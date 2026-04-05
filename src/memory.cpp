#include <cstdint>
#include <fstream>
#include <limits>
#include <sstream>
#include <string>
#include "memory.h"

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>

Rcpp::NumericVector mem_stats() {
    PROCESS_MEMORY_COUNTERS_EX counters;
    bool success = GetProcessMemoryInfo(
        GetCurrentProcess(),
        reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&counters),
        sizeof(counters)
    );

    double used {NA_REAL}, max {NA_REAL};
    if (success) {
        used = static_cast<double>(counters.WorkingSetSize);
        max = static_cast<double>(counters.PeakWorkingSetSize);
    }

    return Rcpp::NumericVector::create(
        Rcpp::_["used"] = used,
        Rcpp::_["max"] = max
    );
}

#elif defined(__APPLE__)
#include <mach/mach.h>

Rcpp::NumericVector mem_stats() {
    mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t status = task_info(
        mach_task_self(),
        MACH_TASK_BASIC_INFO,
        reinterpret_cast<task_info_t>(&info),
        &count
    );

    double used {NA_REAL}, max {NA_REAL};
    if (status == KERN_SUCCESS) {
        used = static_cast<double>(info.resident_size);
        max = static_cast<double>(info.resident_size_max);
    }

    return Rcpp::NumericVector::create(
        Rcpp::_["used"] = used,
        Rcpp::_["max"] = max
    );
}

#else
#include <unistd.h>

double parse_proc_status_value(const std::string& key) {
    std::ifstream status("/proc/self/status");
    if (!status.is_open())
        return NA_REAL;

    std::string line;
    while (std::getline(status, line)) {
        if (line.compare(0, key.size(), key) != 0)
            continue;

        std::istringstream iss(line.substr(key.size()));
        std::uint64_t amount = 0;
        std::string unit;
        if (!(iss >> amount >> unit))
            return NA_REAL;

        if (unit == "kB")
            return static_cast<double>(amount) * 1024.0;

        return static_cast<double>(amount);
    }

    return NA_REAL;
}

Rcpp::NumericVector mem_stats() {
    return Rcpp::NumericVector::create(
        Rcpp::_["used"] = parse_proc_status_value("VmRSS:"),
        Rcpp::_["max"] = parse_proc_status_value("VmHWM:")
    );
}
#endif
