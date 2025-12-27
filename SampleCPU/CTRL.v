`include "lib/defines.vh"

// 定义CTRL模块，控制信号产生与处理
module CTRL(
    input wire rst,  // 输入复位信号

    // 输入：不同阶段的暂停请求
    input wire stallreq_for_ex,    // stall request for execution
    input wire stallreq_for_bru,   // stall request for branch
    input wire stallreq_for_load,  // stall request for load（加载）

    // 输出：流水线各阶段的stall信号
    output reg [`StallBus-1:0] stall  // 暂停信号，控制流水线各阶段的暂停
);
    // stall[0] 表示IF阶段PC是否保持不变，为1表示保持不变
    // stall[1] 表示IF是否暂停，为1表示暂停
    // stall[2] 表示ID是否暂停，为1表示暂停
    // stall[3] 表示EX是否暂停，为1表示暂停
    // stall[4] 表示MEM是否暂停，为1表示暂停
    // stall[5] 表示WB是否暂停，为1表示暂停

    // 根据不同的输入信号，生成合适的stall信号
    always @ (*) begin
        if (rst) begin
            // 如果复位信号为1，所有流水线暂停信号都设为0，恢复正常
            stall = `StallBus'b0;
        end
        // 如果执行阶段ex有暂停请求
        else if (stallreq_for_ex) begin
            // EX阶段及之前的阶段都stall位号543210
            stall = `StallBus'b001111;
        end
        // 如果分支指令bru有暂停请求
        else if (stallreq_for_bru) begin
            // branch所在的ID段及以前都stall
            stall = `StallBus'b000111;
        end
        // 暂时没有处理加载阶段load的暂停请求
        // else if (stallreq_for_load) begin
        //     stall = `StallBus'b000011;
        // end
        else begin
            // 如果没有任何暂停请求，则所有信号都为0，流水线正常执行
            stall = `StallBus'b0;
        end
    end

endmodule
