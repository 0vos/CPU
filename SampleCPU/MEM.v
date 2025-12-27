`include "lib/defines.vh"  // 头文件

// 访问内存
// 可能从EX/MEM流水线寄存器中得到地址读取数据寄存器，并将数据存入MEM/WB流水线寄存器
// 接收并处理访存的结果，并选择写回结果
// 对于需要访存的指令在此段接收访存结果

module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    input wire [31:0] data_sram_rdata,  // 从数据SRAM读取的数据

    input wire [3:0] data_ram_sel,  // 数据RAM的字节选择信号

    input wire [`LoadBus-1:0] ex_load_bus,  // 从EX阶段传递的Load指示信号（控制MEM是否读取内存）

    output wire stallreq_for_load,  // 对Load操作发出的停顿请求信号

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,

    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus
);

    // 暂存来自EX阶段的数据总线和Load指示信号
    reg [`LoadBus-1:0] ex_load_bus_r;  // 暂存Load指示信号
    reg [3:0] data_ram_sel_r;          // 暂存数据RAM选择信号
    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;  // 暂存EX到MEM的数据总线

    // 时钟低到高跳变时更新寄存器的值
    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 复位时清空数据总线寄存器
            data_ram_sel_r <= 4'b0;                // 复位时清空数据RAM选择信号
            ex_load_bus_r <= `LoadBus'b0;          // 复位时清空Load指示信号
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 如果收到冲刷信号，清空数据总线寄存器（当前未使用）
        // end
        else if (stall[3] == `Stop && stall[4] == `NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 当MEM阶段停顿且下一阶段不停顿时，清空寄存器
            data_ram_sel_r <= 4'b0;
            ex_load_bus_r <= `LoadBus'b0;
        end
        else if (stall[3] == `NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;    // 正常情况下，更新数据总线寄存器
            data_ram_sel_r <= data_ram_sel;      // 更新数据RAM选择信号
            ex_load_bus_r <= ex_load_bus;        // 更新Load指示信号
        end
        // 否则保持当前寄存器值（流水线停顿）
    end

    // 解包EX到MEM的数据总线
    wire [31:0] mem_pc;         // 当前指令的PC
    wire data_ram_en;           // 数据RAM使能信号
    wire [3:0] data_ram_wen;    // 数据RAM写使能信号
    wire sel_rf_res;            // 寄存器结果选择信号
    wire rf_we;                 // 寄存器写使能信号
    wire [4:0] rf_waddr;        // 寄存器写地址
    wire [31:0] rf_wdata;       // 寄存器写数据
    wire [31:0] ex_result;      // 来自EX阶段的运算结果
    wire [31:0] mem_result;     // 访存结果

    // 解包Load指示信号
    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw;

    // 访存数据处理
    wire [7:0] b_data;   // 字节数据
    wire [15:0] h_data;  // 半字数据
    wire [31:0] w_data;  // 字数据

    // 解包EX到MEM的数据总线
    assign {
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } = ex_to_mem_bus_r;

    // 解包Load指示信号
    assign {
        inst_lb,  // 4 Load Byte
        inst_lbu, // 3 Load Byte Unsigned
        inst_lh,  // 2 Load Halfword
        inst_lhu, // 1 Load Halfword Unsigned
        inst_lw   // 0 Load Word
    } = ex_load_bus_r;

    // 处理字节、半字和字数据
    // sb指令一次只写入一个字节，根据地址的最低两位选择具体的字节
    // sh指令一次写入两个字节，地址最低两位决定写入位置
    // load指令根据选择信号提取相应的数据部分

    assign b_data = data_ram_sel_r[3] ? data_sram_rdata[31:24] : // 选择信号data_ram_sel_r第3位为1，选最高字节
                    data_ram_sel_r[2] ? data_sram_rdata[23:16] :
                    data_ram_sel_r[1] ? data_sram_rdata[15: 8] :
                    data_ram_sel_r[0] ? data_sram_rdata[ 7: 0] : 8'b0;

    assign h_data = data_ram_sel_r[2] ? data_sram_rdata[31:16] :
                    data_ram_sel_r[0] ? data_sram_rdata[15: 0] : 16'b0;

    assign w_data = data_sram_rdata;

    // 根据Load指令类型选择最终的访存结果
    assign mem_result = inst_lb  ? {{24{b_data[7]}}, b_data} :  // Load Byte，符号扩展24位，拼成32位的word
                        inst_lbu ? {{24{1'b0}}, b_data} :      // Load Byte Unsigned，零扩展，前面24位扩展为0，拼成32位的word
                        inst_lh  ? {{16{h_data[15]}}, h_data} : // Load Halfword
                        inst_lhu ? {{16{1'b0}}, h_data} :      // Load Halfword Unsigned
                        inst_lw  ? w_data :                    // Load Word
                        32'b0;

    // 选择寄存器的写回数据
    assign rf_wdata = sel_rf_res & data_ram_en ? mem_result :
                      ex_result;

    // 将数据从MEM传递到WB
    assign mem_to_wb_bus = {
        mem_pc,    // 69:38
        rf_we,     // 37
        rf_waddr,  // 36:32
        rf_wdata   // 31:0
    };

    // 将数据从MEM传递到寄存器
    assign mem_to_rf_bus = {
        // mem_pc, // 69:38
        rf_we,     // 37
        rf_waddr,  // 36:32
        rf_wdata   // 31:0
    };

    // TODO: 实现stallreq_for_load信号的生成
    // 这里需要根据具体的设计需求来实现停顿请求信号，例如Load-Use数据相关冲突检测

endmodule
