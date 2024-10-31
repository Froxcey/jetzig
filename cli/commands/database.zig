const std = @import("std");

const args = @import("args");
const jetquery = @import("jetquery");
const Migrate = @import("jetquery_migrate");

const util = @import("../util.zig");
const cli = @import("../cli.zig");
const migrate = @import("database/migrate.zig");
const rollback = @import("database/rollback.zig");
const create = @import("database/create.zig");
const drop = @import("database/drop.zig");

/// Command line options for the `database` command.
pub const Options = struct {
    pub const meta = .{
        .usage_summary = "[migrate|rollback|create|drop]",
        .full_text =
        \\Manage the application's database.
        \\
        \\Pass `--help` to any command for more information, e.g.:
        \\
        \\  jetzig database migrate --help
        \\
        ,
    };
};

/// Run the `jetzig generate` command.
pub fn run(
    allocator: std.mem.Allocator,
    options: Options,
    writer: anytype,
    T: type,
    main_options: T,
) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const Action = enum { migrate, rollback, create, drop };
    const map = std.StaticStringMap(Action).initComptime(.{
        .{ "migrate", .migrate },
        .{ "rollback", .rollback },
        .{ "create", .create },
        .{ "drop", .drop },
    });

    const action = if (main_options.positionals.len > 0)
        map.get(main_options.positionals[0])
    else
        null;
    const sub_args: []const []const u8 = if (main_options.positionals.len > 1)
        main_options.positionals[1..]
    else
        &.{};

    return if (main_options.options.help and action == null) blk: {
        try args.printHelp(Options, "jetzig database", writer);
        break :blk {};
    } else if (action == null) blk: {
        const available_help = try std.mem.join(alloc, "|", map.keys());
        std.debug.print("Missing sub-command. Expected: [{s}]\n", .{available_help});
        break :blk error.JetzigCommandError;
    } else if (action) |capture| blk: {
        var cwd = try util.detectJetzigProjectDir();
        defer cwd.close();

        break :blk switch (capture) {
            .migrate => migrate.run(alloc, cwd, sub_args, options, T, main_options),
            .rollback => rollback.run(alloc, cwd, sub_args, options, T, main_options),
            .create => create.run(alloc, cwd, sub_args, options, T, main_options),
            .drop => drop.run(alloc, cwd, sub_args, options, T, main_options),
        };
    };
}
