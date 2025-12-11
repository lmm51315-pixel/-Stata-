cap program drop data_analyze
program define data_analyze, eclass 
    version 17.0
    syntax varlist(min=1 max=6 numeric), ///
        OUTPUT(string) ///
        [IDvar(string) TIMEvar(string)]

    // 计时开始
    local start_time = clock("$S_TIME", "hms")

    // 限制变量数量
    local nvars : word count `varlist'
    if `nvars' > 6 {
        di as error "错误：最多只能分析 6 个变量。你提供了 `nvars' 个。"
        exit 198
    }
	
    // 使用局部宏替代全局宏，避免命名冲突
    local PROF_VARS "`varlist'"
    local PROF_OUTPUT "`output'"
    
    // 识别数据类型
    if ("`idvar'" != "" & "`timevar'" != "") {
		capture xtset `idvar' `timevar'
        if _rc {
            di as error "面板数据设置失败，请检查idvar和timevar"
            exit _rc
        }
        local PROF_TYPE "panel"
        local PROF_PANEL_ID "`idvar'"
        local PROF_TIME_VAR "`timevar'"
    }
    else if ("`timevar'" != "") {
        capture tsset `timevar'
        if _rc {
            di as error "时间序列设置失败，请检查timevar"
            exit _rc
        }
        local PROF_TYPE "ts"
        local PROF_TIME_VAR "`timevar'"
    }
    else {
        local PROF_TYPE "cs"
    }

    // 使用临时文件避免冲突
    tempfile temp_report
    local temp_report_txt "`temp_report'.txt"

    // 调用主程序，通过临时全局变量传递参数
    global TEMP_PROF_VARS "`PROF_VARS'"
    global TEMP_PROF_OUTPUT "`PROF_OUTPUT'"
    global TEMP_PROF_TYPE "`PROF_TYPE'"
    global TEMP_PROF_PANEL_ID "`PROF_PANEL_ID'"
    global TEMP_PROF_TIME_VAR "`PROF_TIME_VAR'"
    global TEMP_REPORT_TXT "`temp_report_txt'"

    // 调用主程序
    capture findfile "data_analyze_core.do"
    if _rc {
        di as error "未找到 data_analyze_core.do"
        macro drop TEMP_PROF_*
        exit 601
    }
    local core_path = r(fn)
    do "`core_path'"

    // 生成HTML报告
    dyndoc "`temp_report_txt'" using "`output'", replace

    // 清理临时全局变量
    macro drop TEMP_PROF_*
    
    // 计时结束
    local end_time = clock("$S_TIME", "hms")
    local run_time = (`end_time' - `start_time') / 1000
    di as result "报告已生成：`output' (运行时间: `run_time' 秒)"
end
