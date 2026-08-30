`timescale 1ns / 1ps

module odd_even_BWT#(
    parameter DATA_WIDTH = 8,
    parameter DATA_VOLUME = 10
    )(
    input logic clk,
    input logic rst,
    
    input logic write_en,
    input logic [DATA_WIDTH - 1 : 0] write_data,
    
    input logic read_en,
    output logic [DATA_WIDTH - 1 : 0] read_data,
    output logic original_line,
    
    input logic be,
    output logic done
    );
    
    //memory
    logic [DATA_WIDTH - 1 : 0] data_memory [DATA_VOLUME - 1 : 0];   //memory that stores data inserted by user
    logic [$clog2(DATA_VOLUME) - 1 : 0] move_memory [DATA_VOLUME - 1 : 0];   //memory that stores cyclic shifts
    
    logic [$clog2(DATA_VOLUME + 1) - 1 : 0] memory_pointer; //this always points to place where new element would be stored
    //or in the case of reading it is used as pointer that starts from 0 and goes to real_data_length
    logic [$clog2(DATA_VOLUME) - 1 : 0] real_data_length;
    
    //additional variables
    logic [1 : 0] state;    //state of module:
    //0 <- normal work (writing data and starting algorithm)
    //1 <- sorting between letters at specific index
    //2 <- sorting between words
    //3 <- reading only
    
    //sorting
    logic odd_even; //state of sorting algorithm
    logic [$clog2(DATA_VOLUME + 1) - 1 : 0] loop_counter;   //loop counter for comparing entire input word (letter by letter)
    logic [DATA_VOLUME - 1 : 1] done_comparing_bus; //bus used for ending comparing loop if all comparators raise 1
    logic [DATA_VOLUME - 1 : 1] separator_bus;  //prevents sorting of already sorted parts of the word
    
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
                            if(data_memory[(move_memory[z - 1] + loop_counter >= real_data_length) ? move_memory[z - 1] + loop_counter - real_data_length : move_memory[z - 1] + loop_counter] >
                            data_memory[(move_memory[z] + loop_counter >= real_data_length) ? move_memory[z] + loop_counter - real_data_length : move_memory[z] + loop_counter]
                            && separator_bus[z] == 0)begin  //this if statement can also be done by using % operator but it is much more hardware demanding
                                move_memory[z - 1] <= move_memory[z];
                                move_memory[z] <= move_memory[z - 1];
                                done_comparing_bus[z] <= 0;
                            end else begin  //setting done flag if swap didn't occur
                                done_comparing_bus[z] <= 1;
                            end
                        end else begin   //setting done flag if there is no data to compare in this comparator
                            done_comparing_bus[z] <= 1;
                        end
                    end
                end else if(state == 2)begin    //separating letteres into itso own groups
                    if(data_memory[(move_memory[z - 1] + loop_counter >= real_data_length) ? move_memory[z - 1] + loop_counter - real_data_length : move_memory[z - 1] + loop_counter] !=
                    data_memory[(move_memory[z] + loop_counter >= real_data_length) ? move_memory[z] + loop_counter - real_data_length : move_memory[z] + loop_counter])begin
                        separator_bus[z] <= 1;
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
            original_line <= 0;
        end else begin
            
            if(state == 0)begin //normal work
                if(write_en && memory_pointer != DATA_VOLUME)begin
                    data_memory[memory_pointer] <= write_data;
                    memory_pointer <= memory_pointer + 1;
                end else if(be)begin
                    state <= 1;
                    odd_even <= 0;
                    loop_counter <= 0;
                    for(int i = 0 ; i < memory_pointer ; i = i + 1)begin    //creating cyclic shifts
                        move_memory[i] <= i;
                    end
                    done_comparing_bus <= 0;
                    separator_bus <= 0;
                    real_data_length <= memory_pointer;
                end
            end else
            
            if(state == 1)begin //sorting between letters at specific index
                if(&done_comparing_bus)begin
                    state <= 2;
                end
                odd_even <= ~ odd_even;
            end else
            
            if(state == 2)begin //sorting between words
                if(loop_counter < memory_pointer)begin  //sorting of next letter
                    loop_counter <= loop_counter + 1;
                    state <= 1;
                    done_comparing_bus <= 0;
                    odd_even <= 0;
                end else begin  //sorting ended
                    state <= 3;
                    done <= 1;
                    original_line <= 0;
                    memory_pointer <= 0;
                end
            end else
            
            if(state == 3)begin //reading data only
                if(memory_pointer > real_data_length)begin    //no more data to read. returns to state 0
                    state <= 0;
                    memory_pointer <= 0;    //reseting emory pointer to 0
                end else if(read_en)begin
                    read_data <= data_memory[move_memory[memory_pointer] == 0 ? real_data_length - 1 : move_memory[memory_pointer] - 1];
                    if(move_memory[memory_pointer] == 0)begin
                        original_line <= 1;
                    end else begin
                        original_line <= 0;
                    end
                    memory_pointer <= memory_pointer + 1;
                end
                done <= 0;
            end
            
        end
    end
    
endmodule
