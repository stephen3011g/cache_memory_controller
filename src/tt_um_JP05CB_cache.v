
`default_nettype none

// ============================================================================
// TinyTapeout top wrapper: tt_um_JP05CB_cache
// - maps 8-bit ui_in to a tiny cache controller
// - uo_out[7] = hit flag
// - uo_out[6:0] = read data (7:0) (we use lower 7 bits to keep it compact)
// ============================================================================
module tt_um_JP05CB_cache (
    input  wire [7:0] ui_in,    // [7]=we, [6:0]=wdata/addr multiplexed by ena protocol below
    output wire [7:0] uo_out,   // [7]=hit, [6:0]=rdata[6:0]
    input  wire [7:0] uio_in,   // unused
    output wire [7:0] uio_out,  // unused
    output wire [7:0] uio_oe,   // unused
    input  wire       ena,      // high = this module active
    input  wire       clk,
    input  wire       rst_n
);
    // Simple control: ui_in[6:4] = wdata (3 bits), ui_in[3:0] = addr (4 bits)
    wire        we    = ui_in[7];
    wire [6:0]  wdata = {4'b0, ui_in[6:4]}; // widen to 7 bits for uo_out
    wire [3:0]  addr  = ui_in[3:0];

    wire [6:0] rdata;
    wire       hit;

    // instantiate the tiny cache controller
    cache_controller_tt #(
        .LINES(4),
        .DATA_W(7),
        .TAG_W(2)   // tag width (addr[3:2])
    ) cache_i (
        .clk   (clk),
        .rst_n (rst_n),
        .ena   (ena),
        .cpu_we(we),
        .cpu_addr(addr),
        .cpu_wdata(wdata),
        .cpu_rdata(rdata),
        .cpu_hit(hit)
    );

    assign uo_out = { hit, rdata[6:0] };
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;
endmodule


// ============================================================================
// cache_controller_tt
// - Scaled version of your controller's FSM and behavior
// - Parameters: number of lines and data width (kept tiny for TT)
// - Backing store is a deterministic function (no external memory pins)
// ============================================================================
module cache_controller_tt #(
    parameter LINES  = 4,       // number of cache lines (power of 2)
    parameter DATA_W = 7,       // data width (bits) -> matches uo_out width
    parameter TAG_W  = 2        // tag width (addr[3:2])
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               ena,
    // CPU-like tiny interface
    input  wire               cpu_we,           // 1 = write, 0 = read
    input  wire [3:0]         cpu_addr,         // [3:2]=tag, [1:0]=index
    input  wire [DATA_W-1:0]  cpu_wdata,
    output reg  [DATA_W-1:0]  cpu_rdata,
    output reg                cpu_hit
);
    // State encoding (same as original)
    localparam IDLE        = 2'b00;
    localparam COMPARE_TAG = 2'b01;
    localparam ALLOCATE    = 2'b10;
    localparam WRITE_BACK  = 2'b11;

    // derived fields
    wire [TAG_W-1:0] tag   = cpu_addr[3:2];
    wire [1:0]       index = cpu_addr[1:0];

    // Small memories implemented as regs (OK at this tiny size)
    reg [DATA_W-1:0] data_mem [0:LINES-1];
    reg [TAG_W-1:0]  tag_mem  [0:LINES-1];
    reg              valid    [0:LINES-1];
    reg              dirty    [0:LINES-1];

    // FSM state and latched request
    reg [1:0] state, next_state;
    reg       cpu_we_q;
    reg [3:0] cpu_addr_q;
    reg [DATA_W-1:0] cpu_wdata_q;

    // Helper: simple deterministic backing store (no external memory)
    function [DATA_W-1:0] backing_data;
        input [3:0] a;
        begin
            // small function: rotate + xor to create deterministic data
            backing_data = {a[1:0], a[3:2], { (DATA_W-4){1'b0} } } ^ { (DATA_W){a[0]} };
        end
    endfunction

    // Hit detection (combinational)
    wire tag_match = (tag_mem[index] == tag);
    wire hit_cmb   = valid[index] & tag_match;

    integer i;
    // Reset/init
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cpu_we_q <= 1'b0;
            cpu_addr_q <= 4'd0;
            cpu_wdata_q <= {DATA_W{1'b0}};
            cpu_rdata <= {DATA_W{1'b0}};
            cpu_hit <= 1'b0;
            for (i=0; i<LINES; i=i+1) begin
                data_mem[i] <= {DATA_W{1'b0}};
                tag_mem[i]  <= {TAG_W{1'b0}};
                valid[i]    <= 1'b0;
                dirty[i]    <= 1'b0;
            end
        end else begin
            // latch requests when ena high and in IDLE
            if (ena && state == IDLE) begin
                cpu_we_q   <= cpu_we;
                cpu_addr_q <= cpu_addr;
                cpu_wdata_q<= cpu_wdata;
            end
            state <= next_state;

            // State actions that update memories/flags
            case (state)
                COMPARE_TAG: begin
                    // on read hit: present data
                    if (hit_cmb && !cpu_we_q) begin
                        cpu_rdata <= data_mem[index];
                        cpu_hit <= 1'b1;
                    end
                    // write on hit will be handled in WRITE_BACK/WRITE path below
                end

                ALLOCATE: begin
                    // bring line from backing store
                    data_mem[index] <= backing_data(cpu_addr_q);
                    tag_mem[index]  <= cpu_addr_q[3:2];
                    valid[index]    <= 1'b1;
                    dirty[index]    <= 1'b0;
                    cpu_rdata <= backing_data(cpu_addr_q);
                    cpu_hit <= 1'b0; // this cycle was a miss
                end

                WRITE_BACK: begin
                    // Simulated write-back: in our tiny model we just clear dirty and then proceed
                    dirty[index] <= 1'b0;
                    valid[index] <= 1'b1;
                end

                IDLE: begin
                    cpu_hit <= 1'b0;
                    // keep cpu_rdata stable
                end

                default: ;
            endcase

            // perform write if state is WRITE (treated within COMPARE_TAG/WRITE path)
            if (state == WRITE_BACK && cpu_we_q) begin
                // after write-back or allocate, perform the CPU write
                data_mem[index] <= cpu_wdata_q;
                tag_mem[index]  <= cpu_addr_q[3:2];
                valid[index]    <= 1'b1;
                dirty[index]    <= 1'b1;
                cpu_hit <= 1'b1;
                cpu_rdata <= cpu_wdata_q;
            end
        end
    end

    // Next-state logic
    always @* begin
        next_state = state;
        if (!ena) begin
            next_state = IDLE;
        end else begin
            case (state)
                IDLE: begin
                    // New request was latched in previous cycle if ena & IDLE
                    // Move to compare on every cycle to evaluate the latched request
                    next_state = COMPARE_TAG;
                end

                COMPARE_TAG: begin
                    if (hit_cmb) begin
                        if (cpu_we_q) begin
                            // write hit: update data and mark dirty (do it through WRITE_BACK state to reuse logic)
                            next_state = WRITE_BACK;
                        end else begin
                            // read hit -> done
                            next_state = IDLE;
                        end
                    end else begin
                        // miss -> allocate (read from backing), if write then will write after allocate
                        next_state = ALLOCATE;
                    end
                end

                ALLOCATE: begin
                    // After allocate, if CPU was write, perform write (go to WRITE_BACK), else return to IDLE
                    if (cpu_we_q) next_state = WRITE_BACK;
                    else next_state = IDLE;
                end

                WRITE_BACK: begin
                    // after write-back (simulated), return to IDLE
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
