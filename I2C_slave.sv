//Verilog code for i2c slave
//In I2c protocol we have many so many devices connected with the same 2 buses scl bus and sda bus
//Every device has its own addr.
//First every device can be able to sample the addr through the sda bus if it matches only it will proceed further.








module slave #(parameter [6:0] slv_addr=7'd7)
  
             (inout sda,
              input clk,
             input rst,
             inout scl);

  parameter idle       =4'd0;
  parameter addr_rx1   =4'd1;
  parameter wack       =4'd2;
  parameter data_rx    =4'd3;
  parameter dack       =4'd4;
  parameter addr_rx2   =4'd5;
  parameter rack       =4'd6;
  parameter tr_data    =4'd7;
  parameter ack        =4'd8;
  parameter stop_st    =4'd9;
  
  parameter addr_ack1  =4'd10;
  parameter addr_ack2  =4'd11;
  parameter addr_ack3  =4'd12;
  parameter restart=  4'd13;
  
  
 
  reg [3:0] pr_state;
  
  reg [7:0]  waddr_reg;
  reg [7:0] raddr_reg;
  reg [7:0] data_reg;
  reg [3:0] count1;
  reg [3:0] count2;
  reg [3:0] count3;
  reg [3:0] bit_count;
  reg [6:0] addr;
  reg rw;
  reg ack_bit;
  reg sda_d;
  reg start;
  reg stop;
  reg scl_d;
  reg scl_pos;
  reg scl_neg;
  reg sda_oe;
  reg scl_oe;
  
  assign sda=sda_oe?1'b0:1'bz;
  assign scl=scl_oe?1'b0:1'bz;
    
  
  always @(posedge clk or posedge rst)begin
    if(rst)begin
      pr_state<=idle;
      waddr_reg<=0;
      raddr_reg<=0;
      data_reg<=0;
      count1<=0;
      count2<=0;
      count3<=0;
      rw<=1;
      ack_bit<=0;
      bit_count<=0;
      addr<=0;
      sda_oe <= 1'b0;
      scl_oe <= 1'b0;
    end
    else begin
      case(pr_state)
        
        idle:begin
          if(start==1)begin
            pr_state<=addr_rx1;
          end
          else
            pr_state<=idle;
        end
 
        addr_rx1:begin
          if(scl_pos)begin
              waddr_reg<={waddr_reg[6:0],sda};
              count1<=count1+1;
          end
          else if(count1==8)begin
            if(scl_neg)begin
              rw<=waddr_reg[0];
                 count1<=0;
                if(slv_addr[6:0]==waddr_reg[7:1])begin
                  //sda_oe<=1;
                  pr_state<=addr_ack1;
                end
                else begin
                  sda_oe<=0;
                end
            end
          end
        end
              
           
        addr_ack1:begin
          sda_oe<=1;            //slave sends ack
            pr_state<=wack;
        end
        
        wack:begin
          if(scl_neg)begin
              sda_oe<=0;             //slave releases sda
            pr_state<=data_rx;
          end
        end
          
        
        data_rx:begin
          if(scl_pos && rw==0)begin
            data_reg<={data_reg[6:0],sda};
            count2<=count2+1;
          end
          else if(count2==8)begin
            if(scl_neg)begin
                count2<=0;
            //  sda_oe<=1; 
                pr_state<=addr_ack2;
              end
          end
        end
        
        addr_ack2:begin
          sda_oe<=1;             //slave sends ack
          pr_state<=dack;
        end
          
        dack:begin 
          if(scl_neg)begin
            sda_oe<=0;               //slave releases sda
            pr_state<=restart;
          end
        end
        
        restart:begin
          if(start==1)begin
            pr_state<=addr_rx2;
          end
        end
        
        
        addr_rx2:begin
          if(scl_pos)begin
            //$display("yes2");
              raddr_reg<={raddr_reg[6:0],sda};
              count3<=count3+1;
          end
          else if(count3==8)begin
            if(scl_neg)begin
            //  $display("yes");
              count3<=0;
              rw<=raddr_reg[0];
              if(slv_addr==raddr_reg[7:1])begin
                 // sda_oe<=1;
                  pr_state<=addr_ack3;
              end
//               else begin
//                 sda_oe<=0;
//               end
            end
          end
        end
        
        addr_ack3:begin
          sda_oe<=1;              //slave sends ack
            pr_state<=rack;
          end
          
       rack:begin
         if(scl_neg)begin 
           sda_oe<=1; 
           sda_oe<=~data_reg[7];
              data_reg<=data_reg<<1;
              bit_count<=bit_count+1;
             //slave releases sda
           pr_state<=tr_data;
         end
       end
                 
       tr_data:begin
         if(scl_neg)begin
           if(bit_count==8)begin
           sda_oe<=0;
              bit_count<=0;
              pr_state<=ack;
           end
           else begin
             if(rw==1)begin
              sda_oe<=~data_reg[7];
              data_reg<=data_reg<<1;
              bit_count<=bit_count+1;
             end
          end
        end 
       end
        
        ack:begin
          if(scl_pos)begin
            ack_bit<=sda;
            pr_state<=(!sda)?stop_st:ack;
          end
//          else if(scl_neg)begin
//        //  sda_oe<=1;
//              if(ack==0)begin
//                pr_state<=stop_st;
//              end
//          end
        end
        
        stop_st:begin
          if(stop)begin
            pr_state<=idle;
          end
        end 
        
        default:pr_state<=idle;
      endcase
    end
  end
  
  always @(posedge clk or posedge rst)begin
    if(rst)begin
      sda_d<=1;
     // start<=0;
     // stop<=0;
    end
    else begin
      sda_d<=sda;     
     // start<=(scl & sda_d & ~sda);
    //  stop<=(scl & ~sda_d & sda);
    end
  end
  
  assign scl_pos=~scl_d & scl;     //detecting posedge 
  assign scl_neg=scl_d & ~scl;     //detecting negedge
  
  assign start=(scl & sda_d & ~sda);   //detecting start
  assign stop=(scl & ~sda_d & sda);    //detecting stop
        
        
        
  always @(posedge clk or posedge rst)begin
    if(rst)
      scl_d<=1;             //scl_d is to store the previous data of scl
    else
      scl_d<=scl;
  end
  
endmodule
  
 
