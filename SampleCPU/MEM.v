`include "lib/defines.vh"

// 对内存访问 load和store
// 可能从EX/MEM流水线寄存器中得到地址读取数据寄存器，并将数据存入MEM/WB流水线寄存器

module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,
    input wire [3:0] data_ram_sel,  // 内存的选择信号，控制不同字长（字节、半字、字等）的访存操作
    input wire [`LoadBus-1:0] ex_load_bus,  // EX阶段传递的加载控制信号（eg是否进行加载）
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus
    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus  // 包含写回寄存器的数据
);
    reg [`LoadBus-1:0] ex_load_bus_r;  // EX加载指令的信号寄存器
    reg [3:0] data_ram_sel_r;  // 内存选择的信号寄存器
    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            // 如果复位信号为高电平，就清空寄存器的内容
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            data_ram_sel_r <= 3'b0;  // 清空数据内存选择信号
            ex_load_bus_r <= `LoadBus'b0;  // 清空EX的加载信号
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            // stall信号指示需要在当前阶段stop，则清空寄存器
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
            data_ram_sel_r <= 3'b0;  // 清空数据内存的选择信号
            ex_load_bus_r <= `LoadBus'b0;  // 清空EX的加载信号
        end
        else if (stall[3]==`NoStop) begin
            // 如果不stall停顿，则更新寄存器中的内容
            ex_to_mem_bus_r <= ex_to_mem_bus;
            data_ram_sel_r <= data_ram_sel;  // 更新数据内存的选择信号
            ex_load_bus_r <= ex_load_bus;  // 更新EX的加载信号
        end
    end

    // 分解总线
    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;

    // 指令型信号
    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw;
    wire [7:0] b_data;  // byte8
    wire [15:0] h_data;  // half-word16
    wire [31:0] w_data;  // word32

    // 解析
    assign {
        mem_pc,         // 75:44 从EX传来的PC地址
        data_ram_en,    // 43 数据内存使能信号
        data_ram_wen,   // 42:39 数据内存写使能信号
        sel_rf_res,     // 38 是否从内存结果选择数据
        rf_we,          // 37 寄存器文件写使能信号
        rf_waddr,       // 36:32 寄存器写地址
        ex_result       // 31:0 EX的计算结果
    } =  ex_to_mem_bus_r;

    // 拆解EX加载指令控制信号
    assign {
        inst_lb,  // 处理byte加载指令
        inst_lbu, // 处理unsignByte加载指令
        inst_lh,  // 处理halfWord加载指令
        inst_lhu, // 处理unsignHalfWord加载指令
        inst_lw   // 处理word加载指令
    } = ex_load_bus_r;

    // 根据选择信号决定写回寄存器的数据是来自内存还是来自EX
    assign rf_wdata = sel_rf_res ? mem_result : ex_result;

    // 如果数据内存使能信号有效，则读取数据，否则为0
    assign mem_result = data_ram_en ? data_sram_rdata : 32'b0;

    // 不同数据类型的加载结果，字节和半字暂时设为0，因为只关心32位word的数据
    assign b_data = 8'b0;  // 字节
    assign h_data = 16'b0;  // 半字
    assign w_data = data_sram_rdata;  // 字，直接使用从内存读取的数据

    // MEM传到WB
    assign mem_to_wb_bus = {
        // mem_pc,     // 69:38 这里暂时没有传递PC地址
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };




endmodule