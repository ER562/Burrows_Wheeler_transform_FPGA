`timescale 1ns / 1ps

module odd_even_RBWT #(
    parameter DATA_WIDTH = 8,
    parameter DATA_POINTS_PER_CYCLE = 3,    //Defines how many data points are in single write or read. Total number of bits in one write is DATA_WIDTH * DATA_POINTS_PER_CYCLE
    parameter DATA_VOLUME = 10
    )(
    input logic clk,
    input logic rst,
    
    input logic write_en,
    input logic [(DATA_WIDTH * DATA_POINTS_PER_CYCLE) - 1 : 0] write_data,
    input logic [$clog2(DATA_POINTS_PER_CYCLE) - 1 :  0] write_data_size,
    input logic [$clog2(DATA_POINTS_PER_CYCLE + 1) - 1 : 0] original_line,
    
    input logic read_en,
    output logic [DATA_WIDTH - 1 : 0] read_data,
    
    input logic be,
    output logic done
    );
    
    //memory
    logic [DATA_WIDTH - 1 : 0] data_memory [DATA_VOLUME - 1 : 0];   //memory that stores data inserted by user
    logic [$clog2(DATA_VOLUME) - 1 : 0] index_memory [DATA_VOLUME - 1 : 0];   //memory that stores indexes of input data
    
    logic [$clog2(DATA_VOLUME + 1) - 1 : 0] memory_pointer; //this always points to place where new element would be stored
    
    logic [$clog2(DATA_VOLUME) - 1 : 0] next_line_idx;  //at the start it is original line index than index of next letter to read
    
    //additional variables
    logic [1 : 0] state;    //state of module:
    //0 <- normal work (writing data and starting algorithm)
    //1 <- sorting
    //2 <- reading only
    
    //sorting
    logic odd_even; //state of sorting algorithm
    logic [DATA_VOLUME - 1 : 1] done_comparing_bus; //bus used for ending comparing loop if all comparators raise 1
    
    //creating comparators
    genvar z;
    generate
        for(z = 1 ; z < DATA_VOLUME ; z = z + 1)begin : comparators
            //creating comparators for odd and even phases
            //this only swap indexes in move_memory
            always_ff @(posedge clk)begin
                if(state == 1)begin    //normal sorting
                    if(odd_even == 0 && z % 2 != 0 || odd_even && z % 2 == 0)begin
                        if(z < memory_pointer)begin //only comparing data that is acually in register
                            if(data_memory[z - 1] > data_memory[z])begin
                                data_memory[z - 1] <= data_memory[z];
                                data_memory[z] <= data_memory[z - 1];
                                index_memory[z - 1] <= index_memory[z];
                                index_memory[z] <= index_memory[z - 1];
                                done_comparing_bus[z] <= 0;
                            end else begin  //setting done flag if swap didn't occur
                                done_comparing_bus[z] <= 1;
                            end
                        end else begin   //setting done flag if there is no data to compare in this comparator
                            done_comparing_bus[z] <= 1;
                        end
                    end
                end
            end
        end
    endgenerate
    
    always_ff @(posedge clk)begin
        if(rst)begin    //reset always have priority
            done <= 0;
            memory_pointer <= 0;
            state <= 0;
            odd_even <= 0;
        end else begin
            
            if(state == 0)begin //normal work
                if(write_en && memory_pointer + write_data_size <= DATA_VOLUME)begin
                    for(int i = 0 ; i < DATA_POINTS_PER_CYCLE ; i++)begin
                        if(i < write_data_size)begin
                            data_memory[memory_pointer + i] <= write_data[i * DATA_WIDTH +: DATA_WIDTH];
                            index_memory[memory_pointer + i] <= memory_pointer + i;
                        end
                    end
                    if(original_line != DATA_POINTS_PER_CYCLE)begin
                        next_line_idx <= memory_pointer + original_line;
                    end
                    memory_pointer <= memory_pointer + write_data_size;
                end else if(be)begin
                    state <= 1;
                    odd_even <= 0;;
                    done_comparing_bus <= 0;
                end
            end else
            
            if(state == 1)begin //sorting
                if(&done_comparing_bus)begin
                    state <= 2;
                    done <= 1;
                end
                odd_even <= ~ odd_even;
            end else
            
            if(state == 2)begin //reading data only
                if(memory_pointer == 0)begin    //no more data to read. returns to state 0
                    state <= 0;
                end else if(read_en)begin
                    read_data <= data_memory[next_line_idx];
                    next_line_idx <= index_memory[next_line_idx];
                    memory_pointer <= memory_pointer - 1;
                end
                done <= 0;
            end
            
        end
    end

    
endmodule