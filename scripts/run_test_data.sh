#!/bin/bash

# MICOS-2024 测试数据运行脚本
# 作者: MICOS-2024 团队
# 版本: 1.0.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示欢迎信息
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🧬 MICOS-2024 🧬                          ║"
    echo "║        智能化宏基因组分析平台 - 测试数据运行脚本              ║"
    echo "║                                                              ║"
    echo "║  🏆 华大基因"猛犸杯"参赛项目                                ║"
    echo "║  🚀 下一代宏基因组分析解决方案                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose 未安装，尝试使用 docker compose"
        if ! docker compose version &> /dev/null; then
            log_error "Docker Compose 未安装，请先安装 Docker Compose"
            exit 1
        fi
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    log_success "依赖检查完成"
}

# 准备测试数据
prepare_test_data() {
    log_info "准备测试数据..."
    
    # 创建必要的目录
    mkdir -p data/test_input
    mkdir -p results/test_output
    mkdir -p logs
    
    # 检查是否已有测试数据
    if [ ! -f "data/test_input/test_sample_1.fastq.gz" ]; then
        log_info "下载测试数据..."
        # 这里可以添加实际的测试数据下载逻辑
        # wget -O data/test_input/test_sample_1.fastq.gz "https://example.com/test_data_1.fastq.gz"
        # wget -O data/test_input/test_sample_2.fastq.gz "https://example.com/test_data_2.fastq.gz"
        
        # 暂时创建模拟数据文件
        touch data/test_input/test_sample_1.fastq.gz
        touch data/test_input/test_sample_2.fastq.gz
        log_warning "使用模拟测试数据，请替换为真实数据"
    fi
    
    log_success "测试数据准备完成"
}

# 运行分析流程
run_analysis() {
    log_info "开始运行 MICOS-2024 分析流程..."
    
    # 设置环境变量
    export COMPOSE_PARALLEL_LIMIT=16
    export MICOS_INPUT_DIR="$(pwd)/data/test_input"
    export MICOS_OUTPUT_DIR="$(pwd)/results/test_output"
    export MICOS_LOG_DIR="$(pwd)/logs"
    
    # 运行质量控制
    log_info "步骤 1/6: 质量控制 (FastQC)"
    cd steps/01_quality_control
    $COMPOSE_CMD up --build
    cd ../..
    
    # 运行数据清洗
    log_info "步骤 2/6: 数据清洗 (KneadData)"
    cd steps/02_read_cleaning
    $COMPOSE_CMD up --build
    cd ../..
    
    # 运行物种分类
    log_info "步骤 3/6: 物种分类 (Kraken2)"
    cd steps/03_taxonomic_profiling_kraken
    $COMPOSE_CMD up --build
    cd ../..
    
    # 运行格式转换
    log_info "步骤 4/6: 格式转换 (BIOM)"
    cd steps/04_taxonomic_conversion_biom
    $COMPOSE_CMD up --build
    cd ../..
    
    # 运行可视化
    log_info "步骤 5/6: 可视化 (Krona)"
    cd steps/05_taxonomic_visualization_krona
    $COMPOSE_CMD up --build
    cd ../..
    
    # 运行QIIME2分析
    log_info "步骤 6/6: 多样性分析 (QIIME2)"
    cd steps/06_qiime2_analysis
    $COMPOSE_CMD up --build
    cd ../..
    
    log_success "分析流程完成！"
}

# 生成报告
generate_report() {
    log_info "生成分析报告..."
    
    # 创建报告目录
    mkdir -p results/reports
    
    # 生成HTML报告
    cat > results/reports/analysis_report.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>MICOS-2024 分析报告</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #667eea; }
        .success { color: #28a745; }
        .info { color: #17a2b8; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧬 MICOS-2024 分析报告</h1>
        <p>智能化宏基因组分析平台 - 测试运行结果</p>
    </div>
    
    <div class="section">
        <h2 class="success">✅ 分析完成</h2>
        <p>所有分析步骤已成功完成，结果文件已保存到 <code>results/test_output</code> 目录。</p>
    </div>
    
    <div class="section">
        <h2 class="info">📊 输出文件</h2>
        <ul>
            <li>质量控制报告: <code>results/test_output/fastqc_reports/</code></li>
            <li>清洗后的序列: <code>results/test_output/kneaddata/</code></li>
            <li>物种分类结果: <code>results/test_output/kraken2/</code></li>
            <li>BIOM格式文件: <code>results/test_output/biom/</code></li>
            <li>Krona可视化: <code>results/test_output/krona/</code></li>
            <li>QIIME2分析: <code>results/test_output/qiime2/</code></li>
        </ul>
    </div>
    
    <div class="section">
        <h2 class="info">🔗 相关链接</h2>
        <ul>
            <li><a href="https://github.com/YOUR_USERNAME/MICOS-2024">项目主页</a></li>
            <li><a href="docs/taxonomic-profiling.md">详细文档</a></li>
        </ul>
    </div>
</body>
</html>
EOF
    
    log_success "分析报告已生成: results/reports/analysis_report.html"
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    # 停止所有容器
    docker stop $(docker ps -aq) 2>/dev/null || true
    log_success "清理完成"
}

# 主函数
main() {
    show_banner
    
    # 设置清理陷阱
    trap cleanup EXIT
    
    check_dependencies
    prepare_test_data
    run_analysis
    generate_report
    
    echo ""
    log_success "🎉 MICOS-2024 测试运行完成！"
    log_info "📊 查看分析报告: results/reports/analysis_report.html"
    log_info "📁 查看输出文件: results/test_output/"
    echo ""
}

# 运行主函数
main "$@"
