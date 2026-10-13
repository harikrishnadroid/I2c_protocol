//I2c master verilog code
//sda_oe is sda enable line
//scl_oe is scl enable line
//to create opendrain concept I have used this sda_oe and scl_oe lines
//In i2c protocol any device can only drive value "0" for driving "1" devices should need to release the sda line then pull up by  pullup resistor 
//which is connected with the vdd.


module master(input aclk,
              input rst,
              input en,
              input [7:0] d_in,
              output reg [7:0] d_out,
              input [6:0] addr,
              input  [6:0] div,
              input rw,
              inout wire sda,
              inout wire scl);
  
  parameter idle      =4'd0;
  parameter start     =4'd1;
  parameter addr_tr1  =4'd2;
  parameter ack_st    =4'd3;
  parameter data_tr   =4'd4;
  parameter re_start  =4'd5;
  parameter addr_tr2  =4'd6;
  parameter master_rx =4'd7;
  parameter stop      =4'd8;
  
  parameter pre_ack1=4'd9;
  parameter pre_ack2=4'd10;
  parameter pre_ack3=4'd11;
  parameter rd_ack=4'd12;
  
  
  reg [3:0] pr_state;
  
  reg [7:0] addr_reg;
  reg [7:0] tx_reg;
  reg [7:0] rx_reg;
  reg [6:0] clk_counter;
  reg [3:0] count;              //for counting the receiving bits
  reg [3:0] waddr_count;
  reg [3:0] data_count;
  reg [3:0] raddr_count;
  reg [8:0] scl_count;
  reg ack;
  reg sda_oe;
  reg scl_oe;
  reg scl_pos;
  reg scl_neg;
  reg scl_d;
  reg ack2;
  
  
  assign sda=(sda_oe==1)?1'b0:1'bz;
  assign scl=(scl_oe==1)?1'b0:1'bz;
  
  assign scl_pos=~scl_d & scl;  //for detecting posedge of scl
  assign scl_neg=scl_d& ~scl;   //for detecting negedge of scl
  
  always @(posedge aclk or posedge rst)begin
    if(rst)begin
      pr_state<=idle;
      count<=0;
      tx_reg<=0;
      rx_reg<=0;
      addr_reg<=0;
      waddr_count<=0;
      raddr_count<=0;
      ack<=1;
      data_count<=0;
      sda_oe<=0;
      scl_oe<=0;
      ack2<=1;
     // slv_rel<=0;
    end
     
    else begin
      case(pr_state)
        idle:begin
          if(en)
            pr_state<=start;
        end
        
        start:begin
          if(en)begin
            if(scl)begin
              sda_oe<=1;
              addr_reg<={addr[6:0],rw};
              pr_state<=addr_tr1;
            end
          end 
        end
        
        addr_tr1:begin 
          tx_reg<=d_in;
          if(scl_neg) begin
            if(waddr_count == 8) begin
              sda_oe <= 1'b0;
              pr_state <= ack_st;
            end
           else begin
             sda_oe <= ~addr_reg[7];
             addr_reg <= addr_reg << 1;
             waddr_count <= waddr_count + 1;
          end
         end
        end
        
       
        
        ack_st:begin
//           if(scl_pos)begin
//             ack<=sda;
//           end
          
         if(scl_pos)begin
            if(waddr_count==8)begin
              waddr_count<=0;
              ack<=sda;
              pr_state<=(!sda)?pre_ack1:ack_st;
              $display("time=%t",$time);
            end
            else if(data_count==8)begin
              data_count<=0;
              ack<=sda;
              pr_state<=(!sda)?pre_ack2:stop;
            end
           else if(raddr_count==8)begin  
             
              raddr_count<=0;
             ack2<=sda;
             pr_state<=(!sda)?master_rx:stop;
           end
          end
        end
        
        pre_ack1:begin
          if(clk_counter == 8'd2 && !scl)begin
            sda_oe<=~tx_reg[7];
            data_count<=data_count+1; 
             tx_reg<=tx_reg<<1;
            pr_state<=data_tr;
          end
        end

        
        data_tr:begin
          if(scl_neg)begin
            if(data_count==8)begin         
              sda_oe<=0;             //master releases the sda
              pr_state<=ack_st;
            end
           else begin
            sda_oe<=~tx_reg[7];
            data_count<=data_count+1; 
             tx_reg<=tx_reg<<1;
           end
          end  
        end
        
        pre_ack2:begin
          if(clk_counter == 8'd2 && !scl)begin
//             sda_oe<=~tx_reg[7];
//             data_count<=data_count+1; 
//              tx_reg<=tx_reg<<1;
            pr_state<=re_start;
          end
        end
          
 
        re_start:begin
          if(scl_neg)begin
           sda_oe<=0;
          end
          else begin
            if(scl &&scl_count==38)begin
              sda_oe<=1;
              addr_reg<={addr[6:0],rw};
              pr_state<=addr_tr2;
            end
          end
        end
        
 
        addr_tr2:begin
          if(scl_neg)begin
            if(raddr_count==8)begin
                  //raddr_count<=0;
                  sda_oe<=0;             //master releases the sda
                  pr_state<=ack_st;
            end
            else begin
               sda_oe<=~addr_reg[7];
               addr_reg<=addr_reg<<1;
               raddr_count<=raddr_count+1;
            end
          end
        end
        
          pre_ack3:begin
           if(clk_counter == 8'd2 && !scl)begin
             pr_state<=master_rx;
           end
         end
          
             
        
        master_rx:begin 
          if(scl_pos)begin
             rx_reg<={rx_reg[6:0],sda};
             count<=count+1;
          end
          else if(count==8)begin
              if(scl_neg)begin
               // sda_oe<=1;             //master sends ack
              count<=0;
              d_out<=rx_reg;
              pr_state<=rd_ack;
            end
          end
        end
        
        rd_ack:begin
          if(scl_neg)begin
            sda_oe<=1;
            pr_state<=stop;
          end
        end
          
        
          
        stop:begin
          if(!en)begin
            if(scl)begin
             sda_oe<=0;
             pr_state<=idle;
            end
          end
        end
        
        default:pr_state<=idle;
      endcase
    end
  end
    

  always @(posedge aclk or posedge rst)begin
    if(rst)
      scl_d<=1;          //scl_d is reg which store the past value of scl
    else
      scl_d<=scl;
  end
   
    
 //scl generation using system clk which is "aclk"   
  always @(posedge aclk or posedge rst)begin
    if(rst)begin
      clk_counter<=0;
      scl_oe<=0;    
      scl_count<=0; 
    end
    else if(pr_state==start || pr_state==idle || pr_state==addr_tr1 || pr_state==data_tr || pr_state==ack_st ||pr_state==re_start || pr_state==addr_tr2 ||pr_state==master_rx || pr_state==stop || pr_state==pre_ack1 || pr_state==pre_ack2 || pr_state==pre_ack3 || pr_state==rd_ack)begin          
      if(clk_counter==div)begin      //div 124
            clk_counter<=0;
            scl_oe<=~scl_oe;
           scl_count<=scl_count+1;
       end
       else begin
            clk_counter<=clk_counter+1;
       end
    end
  end
  
endmodule
      
