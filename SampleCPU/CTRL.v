`include "lib/defines.vh"
module CTRL(
    input wire rst,

    input wire stallreq_for_ex,
    input wire stallreq_for_bru,
    input wire stallreq_for_load,

    // output reg flush,
    // output reg [31:0] new_pc,
    output reg [`StallBus-1:0] stall
);
    // stall[0]表示IF阶段PC是否保持不变，为1表示保持不变。
    // stall[1]表示IF阶段是否暂停，为1表示暂停。
    // stall[2]表示ID阶段是否暂停，为1表示暂停。
    // stall[3]表示EX阶段是否暂停，为1表示暂停。
    // stall[4]表示MEM阶段是否暂停，为1表示暂停。
    // stall[5]表示WB阶段是否暂停，为1表示暂停。


    always @ (*) begin
        if (rst) begin
            stall = `StallBus'b0;
        end
        //todo: stallreq_for_ex, stallreq_for_bru, stallreq_for_load
        else if (stallreq_for_ex) begin
            // EX阶段及之前的阶段都stall位号543210
            stall = `StallBus'b001111;
        end
        else if (stallreq_for_bru) begin
            // branch所在的ID段及以前都stall
            stall = `StallBus'b000111;
        end

        // else if (stallreq_for_load) begin
        //     stall = `StallBus'b000011;
        // end

        else begin
            // 没有stall信号，正常运作
            stall = `StallBus'b0;
        end
    end

endmodule