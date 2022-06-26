const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const testing = std.testing;
const StructField = std.builtin.Type.StructField;

const Entities = @import("entities.zig").Entities;

/// An ECS module can provide components, systems, and global values.
pub fn Module(comptime Params: anytype) @TypeOf(Params) {
    // TODO: validate the type
    return Params;
}

/// Describes a set of ECS modules, each of which can provide components, systems, and more.
pub fn Modules(modules: anytype) @TypeOf(modules) {
    // TODO: validate the type
    return modules;
}

/// Returns the namespaced components struct **type**.
//
/// Consult `namespacedComponents` for how a value of this type looks.
fn NamespacedComponents(comptime modules: anytype) type {
    var fields: []const StructField = &[0]StructField{};
    inline for (std.meta.fields(@TypeOf(modules))) |module_field| {
        const module = @field(modules, module_field.name);
        if (@hasField(@TypeOf(module), "components")) {
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = module_field.name,
                .field_type = @TypeOf(module.components),
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(@TypeOf(module.components)),
            }};
        }
    }
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .is_tuple = false,
            .fields = fields,
            .decls = &[_]std.builtin.Type.Declaration{},
        },
    });
}

/// Extracts namespaces components from modules like this:
///
/// ```
/// .{
///     .renderer = .{
///         .components = .{
///             .location = Vec3,
///             .rotation = Vec3,
///         },
///         ...
///     },
///     .physics2d = .{
///         .components = .{
///             .location = Vec2
///             .velocity = Vec2,
///         },
///         ...
///     },
/// }
/// ```
///
/// Returning a namespaced components value like this:
///
/// ```
/// .{
///     .renderer = .{
///         .location = Vec3,
///         .rotation = Vec3,
///     },
///     .physics2d = .{
///         .location = Vec2
///         .velocity = Vec2,
///     },
/// }
/// ```
///
fn namespacedComponents(comptime modules: anytype) NamespacedComponents(modules) {
    var x: NamespacedComponents(modules) = undefined;
    inline for (std.meta.fields(@TypeOf(modules))) |module_field| {
        const module = @field(modules, module_field.name);
        if (@hasField(@TypeOf(module), "components")) {
            @field(x, module_field.name) = module.components;
        }
    }
    return x;
}

/// Extracts namespaced globals from modules like this:
///
/// ```
/// .{
///     .renderer = .{
///         .globals = struct{
///             foo: *Bar,
///             baz: Bam,
///         },
///         ...
///     },
///     .physics2d = .{
///         .globals = struct{
///             foo: *Instance,
///         },
///         ...
///     },
/// }
/// ```
///
/// Into a namespaced global type like this:
///
/// ```
/// struct{
///     renderer: struct{
///         foo: *Bar,
///         baz: Bam,
///     },
///     physics2d: struct{
///         foo: *Instance,
///     },
/// }
/// ```
///
fn NamespacedGlobals(comptime modules: anytype) type {
    var fields: []const StructField = &[0]StructField{};
    inline for (std.meta.fields(@TypeOf(modules))) |module_field| {
        const module = @field(modules, module_field.name);
        if (@hasField(@TypeOf(module), "globals")) {
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = module_field.name,
                .field_type = module.globals,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(module.globals),
            }};
        }
    }
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .is_tuple = false,
            .fields = fields,
            .decls = &[_]std.builtin.Type.Declaration{},
        },
    });
}

pub fn World(comptime modules: anytype) type {
    const all_components = namespacedComponents(modules);
    return struct {
        allocator: Allocator,
        entities: Entities(all_components),
        globals: NamespacedGlobals(modules),

        const Self = @This();

        pub fn init(allocator: Allocator) !Self {
            return Self{
                .allocator = allocator,
                .entities = try Entities(all_components).init(allocator),
                .globals = undefined,
            };
        }

        pub fn deinit(world: *Self) void {
            world.entities.deinit();
        }

        /// Gets a global value called `.global_tag` from the module named `.module_tag`
        pub fn get(world: *Self, module_tag: anytype, global_tag: anytype) @TypeOf(@field(
            @field(world.globals, @tagName(module_tag)),
            @tagName(global_tag),
        )) {
            return comptime @field(
                @field(world.globals, @tagName(module_tag)),
                @tagName(global_tag),
            );
        }

        /// Sets a global value called `.global_tag` in the module named `.module_tag`
        pub fn set(
            world: *Self,
            comptime module_tag: anytype,
            comptime global_tag: anytype,
            value: @TypeOf(@field(
                @field(world.globals, @tagName(module_tag)),
                @tagName(global_tag),
            )),
        ) void {
            comptime @field(
                @field(world.globals, @tagName(module_tag)),
                @tagName(global_tag),
            ) = value;
        }
    };
}
