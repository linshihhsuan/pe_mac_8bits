module sync_fifo #(
    parameter integer DATA_WIDTH = 32,  // Width of each data item in bits: 32 bits
    parameter integer DEPTH = 8   // Maximum number of items the FIFO can hold
)(
    input wire i_clk,
    input wire i_rst,  // Active-high synchronous reset
    input wire i_wr_en,  // Write enable signal
    input wire [DATA_WIDTH-1:0] i_wr_data,  // Data to be written
    input wire i_rd_en,  // Read enable signal
    
    output reg [DATA_WIDTH-1:0] o_rd_data_r,  // Data read from the FIFO
    output wire o_full,  // 1 when FIFO is completely o_full
    output wire o_empty,  // 1 when FIFO is completel o_empty
    output reg [$clog2(DEPTH+1)-1:0] o_data_count_r  // Tracks current number of items
);

    // ADDR_WIDTH = 5, means no.5 of bits required to represent 32 (0000 to 11111)
    localparam integer ADDR_WIDTH = $clog2(DEPTH);

    // Declare a by-dimensional array to store the data
    reg [DATA_WIDTH-1:0] memory_r [0:DEPTH-1];  // depth = 8, 8 bits elements
    
    // Wr/Rd pointer have extra bits at MSB
    reg [ADDR_WIDTH-1:0] write_pointer_r;
    reg [ADDR_WIDTH-1:0] read_pointer_r;

    // Internal control signals for successful operations
    wire read_accepted;
    wire write_accepted;

    // Status flags generation
    assign o_empty = (o_data_count_r == 0);
    assign o_full = (o_data_count_r == DEPTH);

    // A read is accepted if requested and the FIFO is noo_empty
    assign read_accepted = i_rd_en &&o_empty;

    // A write is accepted if requested and the FIFO is not o_full.
    // Optimization: If the FIFO is o_full but a read is accepted in the same cycle,
    // a slot frees up immediately, so we can also accept the write.
    assign write_accepted = i_wr_en && (!o_full || read_accepted);

    always @(posedge i_clk) begin
        if (i_rst) begin
            // Reset all pointers, counters, and output data
            write_pointer_r <= {ADDR_WIDTH{1'b0}};
            read_pointer_r  <= {ADDR_WIDTH{1'b0}};
            o_data_count_r    <= 0;
            o_rd_data_r       <= {DATA_WIDTH{1'b0}};
        end
        else begin
            // Handle Write Operation
            if (write_accepted) begin
                memory_r[write_pointer_r] <= i_wr_data; // Store data

                // Circular pointer logic: wrap around to 0 if at the end
                if (write_pointer_r == DEPTH - 1)
                    write_pointer_r <= {ADDR_WIDTH{1'b0}};
                else
                    write_pointer_r <= write_pointer_r + 1'b1;
            end

            // Handle Read Operation
            if (read_accepted) begin
                o_rd_data_r <= memory_r[read_pointer_r]; // Fetch data

                // Circular pointer logic: wrap around to 0 if at the end
                if (read_pointer_r == DEPTH - 1)
                    read_pointer_r <= {ADDR_WIDTH{1'b0}};
                else
                    read_pointer_r <= read_pointer_r + 1'b1;
            end

            // Update the data count based on concurrent read/write actions
            case ({write_accepted, read_accepted})
                2'b10: o_data_count_r <= o_data_count_r + 1'b1; // Write only
                2'b01: o_data_count_r <= o_data_count_r - 1'b1; // Read only
                default: o_data_count_r <= o_data_count_r;      // Both or neither (count unchanged)
            endcase
        end
    end

endmodule