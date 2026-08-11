module sync_fifo #(
    parameter integer DATA_WIDTH = 32,  // Width of each data item in bits: 32 bits
    parameter integer DEPTH = 8   // Maximum number of items the FIFO can hold
)(
    input wire clk,
    input wire rst,  // Active-high synchronous reset
    input wire wr_en,  // Write enable signal
    input wire [DATA_WIDTH-1:0] wr_data,  // Data to be written
    input wire rd_en,  // Read enable signal
    
    output reg [DATA_WIDTH-1:0] rd_data,  // Data read from the FIFO
    output wire full,  // 1 when FIFO is completely full
    output wire empty,  // 1 when FIFO is completely empty
    output reg [$clog2(DEPTH+1)-1:0] data_count  // Tracks current number of items
);

    // ADDR_WIDTH = 5, means no.5 of bits required to represent 32 (0000 to 11111)
    localparam integer ADDR_WIDTH = $clog2(DEPTH);

    // Declare a by-dimensional array to store the data
    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];  // depth = 8, 8 bits elements
    
    // Wr/Rd pointer have extra bits at MSB
    reg [ADDR_WIDTH-1:0] write_pointer;
    reg [ADDR_WIDTH-1:0] read_pointer;

    // Internal control signals for successful operations
    wire read_accepted;
    wire write_accepted;

    // Status flags generation
    assign empty = (data_count == 0);
    assign full = (data_count == DEPTH);

    // A read is accepted if requested and the FIFO is not empty
    assign read_accepted = rd_en && !empty;

    // A write is accepted if requested and the FIFO is not full.
    // Optimization: If the FIFO is full but a read is accepted in the same cycle,
    // a slot frees up immediately, so we can also accept the write.
    assign write_accepted = wr_en && (!full || read_accepted);

    always @(posedge clk) begin
        if (rst) begin
            // Reset all pointers, counters, and output data
            write_pointer <= {ADDR_WIDTH{1'b0}};
            read_pointer  <= {ADDR_WIDTH{1'b0}};
            data_count    <= 0;
            rd_data       <= {DATA_WIDTH{1'b0}};
        end
        else begin
            // Handle Write Operation
            if (write_accepted) begin
                memory[write_pointer] <= wr_data; // Store data

                // Circular pointer logic: wrap around to 0 if at the end
                if (write_pointer == DEPTH - 1)
                    write_pointer <= {ADDR_WIDTH{1'b0}};
                else
                    write_pointer <= write_pointer + 1'b1;
            end

            // Handle Read Operation
            if (read_accepted) begin
                rd_data <= memory[read_pointer]; // Fetch data

                // Circular pointer logic: wrap around to 0 if at the end
                if (read_pointer == DEPTH - 1)
                    read_pointer <= {ADDR_WIDTH{1'b0}};
                else
                    read_pointer <= read_pointer + 1'b1;
            end

            // Update the data count based on concurrent read/write actions
            case ({write_accepted, read_accepted})
                2'b10: data_count <= data_count + 1'b1; // Write only
                2'b01: data_count <= data_count - 1'b1; // Read only
                default: data_count <= data_count;      // Both or neither (count unchanged)
            endcase
        end
    end

endmodule