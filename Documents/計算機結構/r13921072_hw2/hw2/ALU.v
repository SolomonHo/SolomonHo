module ALU (
    input           clk,
    input           rst_n,
    input           valid,
    input   [31:0]  in_A,
    input   [31:0]  in_B,
    input   [3:0]   mode,
    output reg      ready,
    output reg [63:0]  out_data
);
// ===============================================
//                    wire & reg
// ===============================================
    reg [63:0] out_data_temp;
    reg [31:0] temp, temp_mul; 
    reg [64:0] prod_rem;
    reg [5:0] count;
    reg [3:0] mode_temp;
    reg [31:0] A_temp,B_temp;
    //reg [31:0] check;
// ===============================================
//                   combinational
// ===============================================
    parameter MAX = 32'h7fffffff;
    parameter MIN = 32'h80000000;
    always @(*) begin
        case (mode)
            4'b0000: begin//add
                temp = $signed(in_A) + $signed(in_B);
                if((in_A[31] == in_B[31]) && (temp[31] != in_A[31]))  begin //overflow 
                    out_data_temp = (in_A[31]) ? {32'd0, MIN} : {32'd0, MAX};          
                end 
                else out_data_temp = {32'd0, temp};
            end
            4'b0001: begin//sub
                temp = $signed(in_A) - $signed(in_B);
                if((in_A[31] != in_B[31]) && (temp[31] != in_A[31]))  begin //overflow 
                    out_data_temp = (in_A[31]) ? {32'd0, MIN} : {32'd0, MAX};          
                end 
                else out_data_temp = {32'd0, temp};        
            end
            4'b0010: out_data_temp = {32'd0, in_A & in_B};//and
            4'b0011: out_data_temp = {32'd0, in_A | in_B};//or
            4'b0100: out_data_temp = {32'd0, in_A ^ in_B};//xor
            4'b0101: out_data_temp = {63'd0, in_A == in_B};//equal
            4'b0110: out_data_temp = {63'd0, $signed(in_A) >= $signed(in_B)};//greater than
            4'b0111: out_data_temp = {32'd0, (in_A >> in_B)};//shift right 
            4'b1000: out_data_temp = {32'd0, (in_A << in_B)};//shift left
            default: out_data_temp = 64'd0;
        endcase
    end

// ===============================================
//                    sequential
// ===============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 0;
            out_data <= 0;
            prod_rem <= 65'd0;
            count <= 0;
        end 
        else if (valid) begin  
            mode_temp <= mode; 
            count <= 0;
            ready <= 0;
            out_data <= out_data_temp;
            case (mode)
                4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110,4'b0111, 4'b1000: begin
                    ready <= 1;
                end
                4'b1001: begin
                    ready <= 0;
                    A_temp <= in_A;
                    //prod_rem <= {33'd0, in_B};
                    if (in_B[0]) begin
                        prod_rem <= ({1'b0, in_A, in_B} >> 1'b1);
                    end 
                    else prod_rem <= ({33'd0, in_B} >> 1'b1);
                end
                4'b1010: begin
                    ready <= 0;
                    B_temp <= in_B;
                    temp_mul <= {31'd0, in_A[31]};
                    //prod_rem <= {33'd0, in_A};
                    //prod_rem <= ({33'd0, in_A} << 1'b1); 
                        //if ( {32'd0, in_A, 1'b0} [63:32] >= in_B) begin
                        if ( temp_mul >= in_B) begin
                            //prod_rem <= {1'b0, {32'd0, in_A, 1'b0}[63:32] - in_B, 31'd0, 1'b1};
                            prod_rem <= {1'b0, {31'd0, in_A[31]} - in_B, 31'd0, 1'b1};
                            //prod_rem[63:32] <= prod_rem[63:32] - B_temp;
                        end 
                        else prod_rem <=  {32'd0, in_A, 1'b0};
                end
                default: ready <= 0;
            endcase
        end else 
        begin
            count <= count + 1;
            case(mode_temp)
                4'b1001: begin//mul
                    if (count < 31) begin //shift 32 times
                        ready <= 0;
                        if (prod_rem[0]) begin
                            prod_rem <= ({{1'b0, prod_rem[63:32]} + {1'b0, A_temp}, prod_rem[31:0]} >> 1'b1);
                        end else prod_rem <= (prod_rem >> 1'b1);
                    end 
                    else if (count == 31) begin
                        ready <= 1;
                        out_data <= prod_rem[63:0];
                        count <= 0;
                        A_temp <= 0;
                        prod_rem <= 0;
                    end 
                    else begin 
                        ready <= 0;
                        prod_rem <= 0;
                    end
                end
                4'b1010:begin //div
                    if (count < 31) begin //shift 32 times
                        ready <= 0;
                        //prod_rem <= (prod_rem << 1'b1); 
                        //if (prod_rem[63:32] >= B_temp) begin
                        if (prod_rem[62:31] >= B_temp) begin
                            //prod_rem[63:32] <= prod_rem[63:32] - B_temp;
                            prod_rem <= {1'b0, prod_rem[62:31] - B_temp, prod_rem[30:0], 1'b1};
                            //check <= prod_rem[62:31] - B_temp;
                        end 
                        else prod_rem <= (prod_rem << 1'b1);
                    end 
                    else if (count == 31) begin
                        ready <= 1;
                        out_data <= prod_rem[63:0];
                        count <= 0;
                        B_temp <= 0;
                        temp <= 0;
                        prod_rem <= 0;
                    end 
                    else begin
                        ready <= 0;
                        prod_rem <= 0;
                    end
                end
                default: begin
                    out_data <= 0;
                    ready <= 0;
                end
            endcase   
        end
    end
endmodule