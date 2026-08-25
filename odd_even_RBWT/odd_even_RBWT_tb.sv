`timescale 1ns / 1ps

module odd_even_RBWT_tb #(
    parameter DATA_WIDTH = 8,
    parameter DATA_VOLUME = 10,
    parameter REAL_INPUT_LENGTH = 6
    )(
    
    );
    
    logic clk;
    logic rst;
    
    logic write_en;
    logic [DATA_WIDTH - 1 : 0] write_data;
    logic original_line;
    
    logic read_en;
    logic [DATA_WIDTH - 1 : 0] read_data;
    
    logic be;
    logic done;
    
    odd_even_RBWT #(
        .DATA_WIDTH (DATA_WIDTH),
        .DATA_VOLUME (DATA_VOLUME)
    ) module_instance (
        .clk (clk),
        .rst (rst),
        
        .write_en (write_en),
        .write_data (write_data),
        .original_line (original_line),
        
        .read_en (read_en),
        .read_data (read_data),
        
        .be (be),
        .done (done)
    );
    
    int input_data [REAL_INPUT_LENGTH - 1 : 0] = '{"n", "n", "b", "a", "a", "a"};
    int output_data [REAL_INPUT_LENGTH - 1 : 0];
    int expected_data [REAL_INPUT_LENGTH - 1 : 0] = '{"b", "a", "n", "a", "n", "a"};
    int original_line_idx = 2;
    
    realtime start_time;
    realtime end_time;
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        rst <= 0;
        write_en <= 0;
        read_en <= 0;
        be <= 0;
        original_line <= 0;
        @(posedge clk);
        
        //reseting module
        rst <= 1;
        @(posedge clk);
        rst <= 0;
        @(posedge clk);
        
        //starting timer
        start_time = $realtime;
        
        //writing to module
        write_en <= 1;
        for(int i = 0 ; i < REAL_INPUT_LENGTH ; i = i + 1)begin
            write_data <= input_data[i];
            if(i == original_line_idx)begin
                original_line <= 1;
            end else begin
                original_line <= 0;
            end
            @(posedge clk);
        end
        write_en <= 0;
        
        //starting algorithm
        be <= 1;
        @(posedge clk);
        be <= 0;
        @(posedge clk);
        
        //waiting for algorithm completition and reading data
        wait(done);
        
        read_en <= 1;
        @(posedge clk);
        @(posedge clk);
        for(int i = 0 ; i < REAL_INPUT_LENGTH ; i = i + 1)begin
            output_data[i] <= read_data;
            @(posedge clk);
        end
        
        end_time = $realtime;
        #10 @(posedge clk);
        //presenting tata
        $display("Algorithm time: %0t", end_time - start_time);
        for(int i = 0 ; i < REAL_INPUT_LENGTH ; i = i + 1)begin
            $display("idx: %0d   input: %0s   output: %0s   expected: %0s", i, input_data[i], output_data[i], expected_data[i]);
        end
        if(output_data == expected_data)begin
            $display("Algorithm works");
        end
        
        $finish;
    end
endmodule
