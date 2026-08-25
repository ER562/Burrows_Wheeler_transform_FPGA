`timescale 1ns / 1ps

module odd_even_BWT_tb #(
    parameter DATA_WIDTH = 8,
    parameter DATA_VOLUME = 20,
    parameter INPUT_ARRAY_LENGTH = 20,   //Length of arrays holding test words. Must be equal or logner than longest input word
    parameter NUMBER_OF_TEST_WORDS = 7  //Exact number of test words
    )(

    );
    
    logic clk;
    logic rst;
    
    logic write_en;
    logic [DATA_WIDTH - 1 : 0] write_data;
    
    logic read_en;
    logic [DATA_WIDTH - 1 : 0] read_data;
    logic original_line;
    
    logic be;
    logic done;
    
    odd_even_BWT #(
        .DATA_WIDTH (DATA_WIDTH),
        .DATA_VOLUME (DATA_VOLUME)
    ) module_instance (
        .clk (clk),
        .rst (rst),
        
        .write_en (write_en),
        .write_data (write_data),
        
        .read_en (read_en),
        .read_data (read_data),
        .original_line (original_line),
        
        .be (be),
        .done (done)
    );
    
    string input_data [0 : NUMBER_OF_TEST_WORDS - 1];
    int input_data_length [0 : NUMBER_OF_TEST_WORDS - 1];
    string expected_data [0 : NUMBER_OF_TEST_WORDS - 1];
    int expected_original_line_idx [0 : NUMBER_OF_TEST_WORDS - 1];
    
    int output_bytes [0 : INPUT_ARRAY_LENGTH - 1]; 
    string output_data;
    int original_line_idx;
    
    int test_passed = 0;
    
    realtime start_time;
    realtime end_time;
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
    
        //writing test data to arrays
        input_data[0] = "banana";
        input_data_length[0] = 6;
        expected_data[0] = "nnbaaa";
        expected_original_line_idx[0] = 3;
        
        input_data[1] = "mississippi";
        input_data_length[1] = 11;
        expected_data[1] = "pssmipissii";
        expected_original_line_idx[1] = 4;
        
        input_data[2] = "abracadabra";
        input_data_length[2] = 11;
        expected_data[2] = "rdarcaaaabb";
        expected_original_line_idx[2] = 2;
        
        input_data[3] = "abcdef";
        input_data_length[3] = 6;
        expected_data[3] = "fabcde";
        expected_original_line_idx[3] = 0;
        
        input_data[4] = "kajak";
        input_data_length[4] = 5;
        expected_data[4] = "kjaka";
        expected_original_line_idx[4] = 3;
        
        input_data[5] = "aaaa";
        input_data_length[5] = 4;
        expected_data[5] = "aaaa";
        expected_original_line_idx[5] = 0;
        
        input_data[6] = "ab";
        input_data_length[6] = 2;
        expected_data[6] = "ba";
        expected_original_line_idx[6] = 0;
    
        //starting tests
        rst <= 0;
        write_en <= 0;
        read_en <= 0;
        be <= 0;
        @(posedge clk);
        
        //reseting module
        rst <= 1;
        @(posedge clk);
        rst <= 0;
        @(posedge clk);
        
        //testing loop
        for(int z = 0 ; z < NUMBER_OF_TEST_WORDS ; z = z + 1)begin
            start_time = $realtime;
            output_data = "";
            
            //writing to module
            write_en <= 1;
            for(int i = 0 ; i < input_data_length[z] ; i = i + 1)begin
                write_data <= input_data[z][i];
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
            for(int i = 0 ; i < input_data_length[z] ; i = i + 1)begin
                output_bytes[i] = read_data;
                if(original_line)begin
                    original_line_idx <= i;
                end
                @(posedge clk);
            end
            read_en <= 0;
            @(posedge clk);
            
            end_time = $realtime;
            
            //presenting data
            output_data = "";
            for(int i = 0; i < input_data_length[z]; i++) begin
                output_data = {output_data, string'(output_bytes[i])};
            end
            $display("\n------------------------------------------------------");
            $display("Test: %0d   word: %0s", z, input_data[z]);
            $display("Algorithm time: %0t", end_time - start_time);
            for(int i = 0 ; i < input_data_length[z] ; i = i + 1)begin
                $display("idx: %0d   input: %0s   output: %0s   expected: %0s", i, input_data[z][i], output_data[i], expected_data[z][i]);
            end
            $display("Original line idx: %0d   Expected original line idx: %0d", original_line_idx, expected_original_line_idx[z]);
            if(output_data == expected_data[z] && original_line_idx == expected_original_line_idx[z])begin
                $display("Test PASSED");
                test_passed++;
            end else begin
                $display("Test FAILED");
            end
            $display("------------------------------------------------------");
        end
        
        $display("\n------------------------------------------------------");
        $display("All tests completed");
        $display("%0d/%0d tests passed", test_passed, NUMBER_OF_TEST_WORDS);
        $display("------------------------------------------------------");
        $finish;
    end
    
endmodule
