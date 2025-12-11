*******************************************************
* data_analyze_core.do - 面板数据按固定个体与时间点处理
*******************************************************

* 获取全局变量
local varlist = "$TEMP_PROF_VARS"  // 变量列表
local outfile = "$TEMP_PROF_OUTPUT"  // 输出文件路径
local datatype = "$TEMP_PROF_TYPE"  // 数据类型（面板数据或时间序列）
local panel_id = "$TEMP_PROF_PANEL_ID"  // 面板数据的面板ID变量
local time_var = "$TEMP_PROF_TIME_VAR"  // 时间序列的时间变量
local report_txt = "$TEMP_REPORT_TXT"  // 报告文件路径

di "Analyzed variables: `varlist'"  // 输出分析的变量
di "Output file: `outfile'"  // 输出文件路径

* 设置面板数据和时间序列的标志
local is_panel = ("`datatype'" == "panel")  // 判断是否为面板数据
local is_ts = ("`datatype'" == "ts")  // 判断是否为时间序列数据

* 检查并安装必要的包（如果没有安装的话）
foreach pkg in estout heatplot {
    capture which `pkg'  // 检查包是否已经安装
    if _rc {  // 如果没有安装
        di "Installing `pkg'..."  // 输出安装信息
        ssc install `pkg', replace  // 安装包
    }
}

* 使用当前工作目录来存储图形
local graph_dir "data_analyze_graphs"  // 图形目录
capture mkdir "`graph_dir'"  // 创建图形存储目录

* 确保所有文件句柄都关闭
capture file close SUMMARY
capture file close REPORT
capture file close ALLFILES

* 直接写入单个HTML文件
capture file close REPORT  // 关闭报告文件（如果已打开）
file open REPORT using "`report_txt'", write replace  // 打开报告文件进行写入

* 写入HTML头部和样式
file write REPORT `"<!DOCTYPE html>"' _n
file write REPORT `"<html>"' _n
file write REPORT `"<head>"' _n
file write REPORT `"<title>Data Analysis Auto Report</title>"' _n
file write REPORT `"<style>"' _n
file write REPORT `"body { font-family: Arial, sans-serif; margin: 20px; }"' _n
file write REPORT `"h1 { color: #333; }"' _n
file write REPORT `"h2 { color: #666; border-bottom: 1px solid #ddd; padding-bottom: 5px; }"' _n
file write REPORT `"h3 { color: #444; margin-top: 20px; }"' _n
file write REPORT `"img { max-width: 100%; height: auto; margin: 10px 0; border: 1px solid #ddd; }"' _n
file write REPORT `".info { background-color: #f5f5f5; padding: 10px; border-radius: 5px; margin-bottom: 20px; }"' _n
file write REPORT `"table { border-collapse: collapse; width: 100%; margin: 15px 0; }"' _n
file write REPORT `"th, td { padding: 8px; text-align: left; border: 1px solid #ddd; }"' _n
file write REPORT `"th { background-color: #f2f2f2; font-weight: bold; }"' _n
file write REPORT `"tr:nth-child(even) { background-color: #f9f9f9; }"' _n
file write REPORT `"tr:hover { background-color: #f0f0f0; }"' _n
file write REPORT `".section { margin-bottom: 30px; }"' _n
file write REPORT `"</style>"' _n
file write REPORT `"</head>"' _n
file write REPORT `"<body>"' _n

* 写入报告的标题和基本信息
file write REPORT `"<h1>Data Analysis Auto Report</h1>"' _n
file write REPORT `"<div class='info'>"' _n
file write REPORT `"<p><strong>Analyzed Variables</strong>: `varlist'</p>"' _n
file write REPORT `"<p><strong>Data Type</strong>: `datatype'</p>"' _n
file write REPORT `"<p><strong>Total Observations</strong>: `=_N'</p>"' _n
file write REPORT `"</div>"' _n _n

* 生成描述性统计表格并直接写入主报告
file write REPORT `"<div class='section'>"' _n
file write REPORT `"<h2>Descriptive Statistics</h2>"' _n
file write REPORT `"<table>"' _n
file write REPORT `"<tr><th>Variable</th><th>N</th><th>Mean</th><th>SD</th><th>Min</th><th>Max</th><th>Median</th></tr>"' _n

preserve
    qui keep `varlist'  // 保留需要分析的变量
    qui tabstat `varlist', stat(n mean sd min max p50) save  // 计算描述性统计量
    matrix stats = r(StatTotal)  // 获取统计量结果
    
    local i 1
    foreach var of varlist `varlist' {
        file write REPORT `"<tr>"'  // 写入表格行
        file write REPORT `"<td>`var'</td>"'  // 变量名
        file write REPORT `"<td>`=stats[1,`i']'</td>"'  // N值
        file write REPORT `"<td>`=string(stats[2,`i'], "%8.3f")'</td>"'  // 平均值
        file write REPORT `"<td>`=string(stats[3,`i'], "%8.3f")'</td>"'  // 标准差
        file write REPORT `"<td>`=stats[4,`i']'</td>"'  // 最小值
        file write REPORT `"<td>`=stats[5,`i']'</td>"'  // 最大值
        file write REPORT `"<td>`=stats[6,`i']'</td></tr>"' _n  // 中位数
        local i = `i' + 1
    }
restore

file write REPORT `"</table>"' _n
file write REPORT `"</div>"' _n _n

* 生成缺失值分析表格并直接写入主报告
file write REPORT `"<div class='section'>"' _n
file write REPORT `"<h2>Missing Value Analysis</h2>"' _n
file write REPORT `"<table>"' _n
file write REPORT `"<tr><th>Variable</th><th>Obs</th><th>Missing</th><th>Missing %</th></tr>"' _n

local i 1
foreach var of varlist `varlist' {
    quietly count if missing(`var')  // 计算缺失值数量
    local missing_count = r(N)  // 缺失值个数
    local total_count = _N  // 总观察数
    local missing_pct = round((`missing_count' / `total_count') * 100, 0.1)  // 缺失百分比
    
    file write REPORT `"<tr>"'  // 写入表格行
    file write REPORT `"<td>`var'</td>"'  // 变量名
    file write REPORT `"<td>`total_count'</td>"'  // 总观察数
    file write REPORT `"<td>`missing_count'</td>"'  // 缺失值数量
    file write REPORT `"<td>`missing_pct'%</td></tr>"' _n  // 缺失值百分比
    local i = `i' + 1
}

file write REPORT `"</table>"' _n
file write REPORT `"</div>"' _n _n

* 图表生成部分
file write REPORT `"<div class='section'>"' _n
file write REPORT `"<h2>Single-Variable Distribution</h2>"' _n

foreach v of varlist `varlist' {
    local vlabel : variable label `v'  // 获取变量标签
    if "`vlabel'" == "" local vlabel "`v'"  // 如果没有标签，使用变量名
    
    quietly {
        count if missing(`v')  // 计算缺失值数量
        local missing_count = r(N)
        qui levelsof `v', local(vals) clean  // 获取变量的所有取值
        local unique_vals = wordcount("`vals'")  // 计算取值的数量
        
        if `unique_vals' <= 10 & `missing_count' < _N {  // 类别变量，且非全缺失
            // 生成条形图
            graph bar (count), over(`v') ///
                title("`vlabel'") ///
                name(g_`v'_bar, replace)
            graph export "`graph_dir'/`v'_bar.png", replace width(500)
            
            // 写入报告
            file write REPORT `"<h3>`vlabel' (Categorical Variable)</h3>"' _n
            file write REPORT `"<img src="`graph_dir'/`v'_bar.png" alt="`vlabel' Bar Chart">"' _n _n
        }
        else if `missing_count' < _N {  // 连续变量，且非全缺失
            // 生成直方图
            histogram `v', percent ///
                title("`vlabel'") ///
                name(g_`v'_hist, replace)
            graph export "`graph_dir'/`v'_hist.png", replace width(400)
            
            // 生成箱线图
            graph box `v', ///
                title("`vlabel'") ///
                name(g_`v'_box, replace)
            graph export "`graph_dir'/`v'_box.png", replace width(400)
            
            // 写入报告
            file write REPORT `"<h3>`vlabel' (Continuous Variable)</h3>"' _n
            file write REPORT `"<img src="`graph_dir'/`v'_hist.png" alt="`vlabel' Histogram">"' _n
            file write REPORT `"<img src="`graph_dir'/`v'_box.png" alt="`vlabel' Box Plot">"' _n _n
        }
        else {  // 全部缺失
            file write REPORT `"<h3>`vlabel' (All Missing)</h3>"' _n
            file write REPORT `"<p>All observations are missing for this variable.</p>"' _n _n
        }
    }
}

*******************************************************
* 时间序列/面板数据分析 - 按时间序列和横截面处理
*******************************************************

* 判断数据类型是时间序列或面板数据
if `is_ts' | `is_panel' {
    file write REPORT `"<div class='section'>"' _n
    file write REPORT `"<h2>Time Trend Analysis</h2>"' _n

    * 对于时间序列数据设置时间序列变量
    if `is_ts' tsset `time_var'  // 设置时间序列数据

    * 对于面板数据设置面板数据变量
    if `is_panel' xtset `panel_id' `time_var'  // 设置面板数据

    foreach v of varlist `varlist' {
        if !inlist("`v'", "`time_var'", "`panel_id'") {
            quietly {
                * 如果是时间序列数据，生成时间序列图
                if `is_ts' {
                    tsline `v', title("`vlabel' over Time") name(g_`v'_ts, replace)  // 时间序列分析
                    graph export "`graph_dir'/`v'_ts.png", replace width(500)
                    file write REPORT `"<img src="`graph_dir'/`v'_ts.png" alt="`vlabel' Time Series Plot">"' _n
                }

                * 如果是面板数据，按时间进行分析
                if `is_panel' {
                    * 按时间序列分析（每个面板单位按时间计算均值）
                    qui collapse (mean) `v', by(`panel_id' `time_var')  // 对每个面板单位按时间计算均值
                    file write REPORT `"<h3>Time Series of `vlabel' (Panel Data)</h3>"' _n
                    
                    tsset `panel_id' `time_var'  // 设置面板数据
                    tsline `v', title("`vlabel' over Time (Panel)") name(g_`v'_panel_ts, replace)  // 面板时间序列图
                    graph export "`graph_dir'/`v'_panel_ts.png", replace width(500)
                    file write REPORT `"<img src="`graph_dir'/`v'_panel_ts.png" alt="`vlabel' Panel Time Series Plot">"' _n
                    
                    * 按固定时间点（横截面分析）分析
                    qui su `time_var', meanonly
                    local last_time = r(max)  // 获取最新的时间点
                    qui keep if `time_var' == `last_time'  // 仅保留该时间点的数据
                    
                    file write REPORT `"<h3>Cross-Sectional Analysis of `vlabel' at Time `last_time'</h3>"' _n
                    file write REPORT `"<table>"' _n
                    file write REPORT `"<tr><th>Variable</th><th>N</th><th>Mean</th><th>SD</th><th>Min</th><th>Max</th><th>Median</th></tr>"' _n
                    
                    qui tabstat `v', stat(n mean sd min max p50)  // 计算描述性统计量
                    local stats = r(StatTotal)
                    
                    file write REPORT `"<tr>"'
                    file write REPORT `"<td>`vlabel'</td>"'
                    file write REPORT `"<td>`=stats[1,1]'</td>"'
                    file write REPORT `"<td>`=string(stats[2,1], "%8.3f")'</td>"'
                    file write REPORT `"<td>`=string(stats[3,1], "%8.3f")'</td>"'
                    file write REPORT `"<td>`=stats[4,1]'</td>"'
                    file write REPORT `"<td>`=stats[5,1]'</td>"'
                    file write REPORT `"<td>`=stats[6,1]'</td></tr>"' _n
                    
                    file write REPORT `"</table>"' _n _n
                }
            }
        }
    }
    file write REPORT `"</div>"' _n _n
}


* 报告结尾
file write REPORT `"<hr>"' _n
file write REPORT `"<div style='text-align: center; color: #777; font-size: 0.9em;'>"' _n
file write REPORT `"<p><em>Report Generation Time: `c(current_date)' `c(current_time)'</em></p>"' _n
file write REPORT `"<p><em>Stata Version: `c(version)'</em></p>"' _n
file write REPORT `"</div>"' _n

file write REPORT `"</body>"' _n
file write REPORT `"</html>"' _n

file close REPORT  // 关闭报告文件

* 清理图形对象
capture graph close _all

* 删除临时HTML文件（如果存在）
capture erase "summary_stats.html"
capture erase "missing_stats.html"

di "Core analysis complete - Single HTML report generated: `report_txt'"  // 输出完成信息
