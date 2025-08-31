
`default_nettype none

module tt_um_cache (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // IOs
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,

    input  wire clk,            // clock
    input  wire rst_n,          // reset (active low)
    input  wire ena             // enable
);

    // Tiny 4-entry, 2-bit wide cache
    reg [1:0] cache_data [0:3];
    reg [1:0] cache_addr [0:3];
    reg       cache_valid [0:3];

    wire req_valid = ui_in[0];
    wire req_rw    = ui_in[1];
    wire [1:0] addr = ui_in[3:2];
    wire [1:0] data_in = ui_in[5:4];

    reg [1:0] data_out;
    reg hit;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0;i<4;i=i+1) begin
                cache_valid[i] <= 0;
                cache_data[i]  <= 0;
                cache_addr[i]  <= 0;
            end
            data_out <= 0;
            hit <= 0;
        end else if (ena && req_valid) begin
            hit <= 0;
            for (i=0;i<4;i=i+1) begin
                if (cache_valid[i] && cache_addr[i] == addr) begin
                    hit <= 1;
                    if (req_rw) begin
                        cache_data[i] <= data_in; // write
                    end else begin
                        data_out <= cache_data[i]; // read
                    end
                end
            end
            if (!hit && req_rw) begin
                cache_valid[addr] <= 1;
                cache_addr[addr]  <= addr;
                cache_data[addr]  <= data_in;
            end
        end
    end

    // outputs
    assign uo_out[0] = hit;
    assign uo_out[2:1] = data_out;
    assign uo_out[7:3] = 0;

    // no bidirs used
    assign uio_out = 0;
    assign uio_oe  = 0;

endmodule


`default_nettype wire


