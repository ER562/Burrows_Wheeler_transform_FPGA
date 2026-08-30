`timescale 1ns / 1ps

module odd_even_BWT#(
    parameter DATA_WIDTH = 8,
    parameter DATA_POINTS_PER_CYCLE = 3,    //Defines how many data points are in single write or read. Total number of bits in one write is DATA_WIDTH * DATA_POINTS_PER_CYCLE
    parameter DATA_VOLUME = 10
    )(
    input logic clk,
    input logic rst,
    
    input logic write_en,
    input logic [(DATA_WIDTH * DATA_POINTS_PER_CYCLE) - 1 : 0] write_data,
    input logic [$clog2(DATA_POINTS_PER_CYCLE) - 1 :  0] write_data_size,
    
    input logic read_en,
    output logic [(DATA_WIDTH * DATA_POINTS_PER_CYCLE) - 1 : 0] read_data,
    output logic [$clog2(DATA_POINTS_PER_CYCLE + 1) - 1 : 0] original_line,
    
    input logic be,
    output logic done
    );
    
    //memory
    logic [DATA_WIDTH - 1 : 0] insert_memory [DATA_VOLUME - 1 : 0];   //memory that stores data inserted by user
    logic [DATA_WIDTH - 1 : 0] sorting_memory [DATA_VOLUME - 1 : 0];   //memory used for sorting
    logic [$clog2(DATA_VOLUME) - 1 : 0] insert_move_memory [DATA_VOLUME - 1 : 0];   //memory that stores cyclic shifts
    logic [$clog2(DATA_VOLUME) - 1 : 0] sorting_move_memory [DATA_VOLUME - 1 : 0];   //memory that stores cyclic shifts
    
    logic [$clog2(DATA_VOLUME + 1) - 1 : 0] insert_memory_pointer;  //pointer used for writing data
    //this always points to place where new element would be stored
    //or in the case of reading it is used as pointer that starts from 0 and goes to real_data_length
    logic [$clog2(DATA_VOLUME + 1) - 1 : 0] sorting_memory_pointer;    //pointer that holds data l;ength taht is currently sorted
    logic [$clog2(DATA_VOLUME) - 1 : 0] real_data_length;
    
    logic read_write;   //0 -> only writing is permitted, 1 -> only reading
    
    //sorting
    logic odd_even; //state of sorting algorithm
    logic [$clog2(DATA_VOLUME + 1) - 1 : 0] loop_counter;   //loop counter for comparing entire input word (letter by letter)
    logic [DATA_VOLUME - 1 : 1] done_comparing_bus; //bus used for ending comparing loop if all comparators raise 1
    logic [DATA_VOLUME - 1 : 1] separator_bus;  //prevents sorting of already sorted parts of the word
    
    logic [1 : 0] state;    //used only in sorting algorithm
    
    always_ff @(posedge clk)begin
        if(rst)begin    //reset always have priority
            done <= 0;
            insert_memory_pointer <= 0;
            sorting_memory_pointer <= 0;
            state <= 0;
            read_write <= 0;
            real_data_length <= 0;
        end else begin
            
            //writing
            if(write_en && read_en == 0 && read_write == 0 && insert_memory_pointer + write_data_size <= DATA_VOLUME)begin
                for(int i = 0 ; i < DATA_POINTS_PER_CYCLE ; i++)begin
                    if(i < write_data_size)begin
                        insert_memory[insert_memory_pointer + i] <= write_data[i * DATA_WIDTH +: DATA_WIDTH];
                    end
                end
                insert_memory_pointer <= insert_memory_pointer + write_data_size;
            end
            
            //reading
            if(read_en && write_en == 0 && read_write)begin
                automatic int read_data_points = 0;
                automatic int original_line_idx = DATA_POINTS_PER_CYCLE;
                for(int i = 0 ; i < DATA_POINTS_PER_CYCLE ; i++)begin
                    if(insert_memory_pointer + i < real_data_length)begin
                        read_data[i * DATA_WIDTH +: DATA_WIDTH] <= insert_memory[insert_move_memory[insert_memory_pointer + i] == 0 ? real_data_length - 1 : insert_move_memory[insert_memory_pointer + i] - 1];
                        if(insert_move_memory[insert_memory_pointer + i] == 0)begin
                            original_line_idx = i;
                        end
                        read_data_points++;
                    end
                end
                original_line <= original_line_idx;
                if(insert_memory_pointer + read_data_points >= real_data_length)begin   //all data is read. Pointer must return to 0
                    insert_memory_pointer <= 0;
                    read_write <= 0;
                end else begin
                    insert_memory_pointer <= insert_memory_pointer + read_data_points;  //there is data left
                end
            end
            
            //starting algorithm
            if(be && state == 0 )begin
                if(write_en == 0 && read_en == 0)begin   //cannot be used when algorithm already started
                    if(real_data_length != 0)begin
                        read_write <= 1;
                    end
                    
                    if(insert_memory_pointer != 0)begin
                        odd_even <= 0;
                        state <= 1;
                        loop_counter <= 0;
                        done_comparing_bus <= 0;
                        separator_bus <= 0;
                    end
                    
                    insert_memory_pointer <= sorting_memory_pointer;
                    sorting_memory_pointer <= insert_memory_pointer;
                    
                    for(int i = 0 ; i < DATA_VOLUME ; i++)begin
                        sorting_memory[i] <= insert_memory[i];
                        insert_memory[i] <= sorting_memory[i];
                        
                        sorting_move_memory[i] <= i;
                        insert_move_memory[i] <= sorting_move_memory[i];  
                    end
                end
            end
            
            //sorting
            if(state == 0)begin
                done <= 0;
            end 
            
            else if(state == 1)begin //sorting between letters at specific index
                if(&done_comparing_bus)begin
                    state <= 2;
                end
                odd_even <= ~ odd_even;
                
                //comparator
                for(int z = 1 ; z < DATA_VOLUME ; z = z + 1)begin : comparators
                    //creating comparators for odd and even phases
                    //this only swap indexes in move_memory
                    if(odd_even == 0 && z % 2 != 0 || odd_even && z % 2 == 0)begin
                        if(z < sorting_memory_pointer)begin //only comparing data that is acually in register
                            if(sorting_memory[(sorting_move_memory[z - 1] + loop_counter >= sorting_memory_pointer) ? sorting_move_memory[z - 1] + loop_counter - sorting_memory_pointer : sorting_move_memory[z - 1] + loop_counter] >
                            sorting_memory[(sorting_move_memory[z] + loop_counter >= sorting_memory_pointer) ? sorting_move_memory[z] + loop_counter - sorting_memory_pointer : sorting_move_memory[z] + loop_counter]
                            && separator_bus[z] == 0)begin  //this if statement can also be done by using % operator but it is much more hardware demanding
                                sorting_move_memory[z - 1] <= sorting_move_memory[z];
                                sorting_move_memory[z] <= sorting_move_memory[z - 1];
                                done_comparing_bus[z] <= 0;
                            end else begin  //setting done flag if swap didn't occur
                                done_comparing_bus[z] <= 1;
                            end
                        end else begin   //setting done flag if there is no data to compare in this comparator
                            done_comparing_bus[z] <= 1;
                        end
                    end
                end
                
            end else
            
            if(state == 2)begin //sorting between words
                if(loop_counter < sorting_memory_pointer)begin  //sorting of next letter
                    loop_counter <= loop_counter + 1;
                    state <= 1;
                    done_comparing_bus <= 0;
                    odd_even <= 0;
                end else begin  //sorting ended
                    state <= 0;
                    done <= 1;
                    original_line <= 0;
                    sorting_memory_pointer <= 0;
                    real_data_length <= sorting_memory_pointer;
                end
                
                for(int z = 1 ; z < DATA_VOLUME ; z = z + 1)begin : separators
                    if(sorting_memory[(sorting_move_memory[z - 1] + loop_counter >= sorting_memory_pointer) ? sorting_move_memory[z - 1] + loop_counter - sorting_memory_pointer : sorting_move_memory[z - 1] + loop_counter] !=
                        sorting_memory[(sorting_move_memory[z] + loop_counter >= sorting_memory_pointer) ? sorting_move_memory[z] + loop_counter - sorting_memory_pointer : sorting_move_memory[z] + loop_counter])begin
                        separator_bus[z] <= 1;
                    end
                end
            end
            
        end
    end
    
endmodule
