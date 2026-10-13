//top module
//every connection between the modules will be connected with wires in this module


module top(input aclk,
           input rst,
           input en,
           input [7:0] d_in,
           output [7:0] d_out,
           input [6:0] addr,
           input [6:0] div,
           input rw,
           input clk);

  
 //By using this wires we have conecetd with the master to slave modules 
  wire dout;          
  wire w_addr;
  wire sda;
  wire scl;
  
  pullup(sda);            //pullup(sda) physically sda is connecting with vdd
  pullup(scl);            //pullup means pulling scl to high
  
  master m1(.aclk(aclk),
            .rst(rst),
            .d_in(d_in),
            .en(en),
            .d_out(d_out),
            .addr(addr),
            .div(div),
            .rw(rw),
            .sda(sda),
            .scl(scl));
  
  slave s1(.sda(sda),
           .clk(clk),
           .scl(scl),
           .rst(rst));
endmodule
  
  
           
