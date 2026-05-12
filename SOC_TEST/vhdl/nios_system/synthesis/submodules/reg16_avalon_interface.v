module reg16_avalon_interface (
    input        clock,
    input        resetn,

    // Avalon-MM slave signals
    input [15:0] writedata,
    output [15:0] readdata,
    input        write,
    input        read,
    input [1:0]  byteenable,
    input        chipselect,

    // Conduit export signal
    output [15:0] Q_export
);

// Internal signals
wire [1:0]  local_byteenable;
wire [15:0] to_reg;
wire [15:0] from_reg;

// Data from Avalon bus to internal register
assign to_reg = writedata;

// Only allow write when the component is selected
assign local_byteenable = (chipselect & write) ? byteenable : 2'b00;

// Internal 16-bit register
reg16 U1 (
    .clock(clock),
    .resetn(resetn),
    .D(to_reg),
    .byteenable(local_byteenable),
    .Q(from_reg)
);

// Avalon read data
assign readdata = from_reg;

// Export register value outside Qsys
assign Q_export = from_reg;

endmodule