// OBS Studio portable launcher (GPL-2.0-or-later)
// Uses OBS's own --portable mode. Never modifies a host registry key.
// Windows SDK + MSVC /std:c++17. No script embedding, process injection or elevation.
#include <windows.h>
#include <winioctl.h>
#include <tlhelp32.h>
#include <shellapi.h>
#include <filesystem>
#include <string>
#include <vector>
#include <set>
#include <fstream>
#include <system_error>
#include <chrono>
#include <thread>
#include <algorithm>
#include <stdexcept>
#include <cstring>
#include <cwctype>
#include <functional>
#include <utility>
#include <cstdint>
#include <cstddef>
#include <climits>
#include <iterator>

namespace fs = std::filesystem;
using Path = fs::path;

static void show_error(const std::wstring& message) {
    MessageBoxW(nullptr, message.c_str(), L"OBS Studio Portable", MB_OK | MB_ICONERROR);
}
static std::wstring lower(std::wstring s) {
    std::transform(s.begin(), s.end(), s.begin(), [](wchar_t c) { return (wchar_t)towlower(c); });
    return s;
}
static std::wstring env(const wchar_t *name) {
    DWORD size = GetEnvironmentVariableW(name, nullptr, 0);
    if (!size) return L"";
    std::wstring result(size, L'\0');
    DWORD n = GetEnvironmentVariableW(name, result.data(), size);
    if (!n || n >= size) return L"";
    result.resize(n);
    return result;
}
static Path executable_path() {
    std::wstring result(32768, L'\0');
    DWORD n = GetModuleFileNameW(nullptr, result.data(), (DWORD)result.size());
    if (!n || n >= result.size()) throw std::runtime_error("Cannot identify launcher path");
    result.resize(n);
    return Path(result);
}
static bool same_bytes(const Path& a, const Path& b) {
    std::error_code ec;
    if (!fs::is_regular_file(a, ec) || !fs::is_regular_file(b, ec)) return false;
    if (fs::file_size(a, ec) != fs::file_size(b, ec) || ec) return false;
    std::ifstream fa(a, std::ios::binary), fb(b, std::ios::binary);
    if (!fa || !fb) return false;
    char ca[65536], cb[65536];
    for (;;) {
        fa.read(ca, sizeof(ca)); fb.read(cb, sizeof(cb));
        if (fa.gcount() != fb.gcount()) return false;
        if (memcmp(ca, cb, (size_t)fa.gcount()) != 0) return false;
        if (!fa.gcount()) return true;
    }
}
static void log_line(const Path& file, const std::wstring& line) {
    std::ofstream log(file, std::ios::app | std::ios::binary);
    if (!log) return;
    // Diagnostics are ASCII-only for predictable encoding; non-ASCII path details remain in Windows error UI.
    for (auto c : line) log << ((c >= 32 && c <= 126) ? (char)c : '?');
    log << '\n';
}
static bool is_reparse(const Path& p) {
    DWORD attr = GetFileAttributesW(p.c_str());
    return attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
}
static void safe_copy_tree(const Path& source, const Path& destination, const Path& conflict_root) {
    if (is_reparse(source)) throw std::runtime_error("Refuse to capture reparse point");
    fs::create_directories(destination);
    // The iterator includes empty directories: they are explicitly recreated in Data.
    for (fs::recursive_directory_iterator it(source), end; it != end; ++it) {
        const Path p = it->path();
        if (is_reparse(p)) {
            if (it->is_directory()) it.disable_recursion_pending();
            continue;
        }
        const Path rel = fs::relative(p, source);
        const Path dest = destination / rel;
        if (it->is_directory()) { fs::create_directories(dest); continue; }
        if (!it->is_regular_file()) continue;
        fs::create_directories(dest.parent_path());
        if (fs::exists(dest) && !same_bytes(p, dest)) {
            // Never silently replace an existing Data file. Keep a verified backup.
            const Path backup = conflict_root / rel;
            fs::create_directories(backup.parent_path());
            if (!fs::exists(backup)) {
                fs::copy_file(dest, backup);
                if (!same_bytes(dest, backup)) throw std::runtime_error("Conflict backup verification failed");
            }
        }
        if (!same_bytes(p, dest)) fs::copy_file(p, dest, fs::copy_options::overwrite_existing);
        if (!same_bytes(p, dest)) throw std::runtime_error("Data copy verification failed");
    }
}
// Only a directory that did not exist before this portable session may be
// claimed. A verify-before-remove routine prevents deleting a late new file
// or deleting a file whose contents changed after it was copied to Data.
// In particular, do not call remove_all() on a shared ProgramData directory.
static void safe_capture_and_remove(const Path& source, const Path& destination,
                                    const Path& conflict_root) {
    if (is_reparse(source)) throw std::runtime_error("External root is a reparse point");
    std::vector<Path> files;
    std::vector<Path> directories;
    std::error_code ec;
    if (!fs::is_directory(source, ec) || ec) throw std::runtime_error("External root unavailable");
    for (fs::recursive_directory_iterator it(source), end; it != end; ++it) {
        Path entry = it->path();
        if (is_reparse(entry)) throw std::runtime_error("Refuse to remove external tree containing a reparse point");
        if (it->is_directory()) directories.push_back(fs::relative(entry, source));
        else if (it->is_regular_file()) files.push_back(fs::relative(entry, source));
        else throw std::runtime_error("Unknown external object; leave host folder intact");
    }
    safe_copy_tree(source, destination, conflict_root);
    // Check the complete original inventory still exists and was preserved.
    for (const auto& rel : directories) {
        if (!fs::is_directory(source / rel) || !fs::is_directory(destination / rel))
            throw std::runtime_error("External directory changed during capture");
    }
    for (const auto& rel : files) {
        if (!same_bytes(source / rel, destination / rel))
            throw std::runtime_error("External file changed during capture");
    }
    // Do not delete any files if another application added to this tree while
    // it was copied. This is a safety check, not a claim of process ownership.
    size_t observed = 0;
    for (fs::recursive_directory_iterator it(source), end; it != end; ++it) {
        if (is_reparse(it->path())) throw std::runtime_error("New external reparse point appeared");
        ++observed;
    }
    if (observed != directories.size() + files.size())
        throw std::runtime_error("External tree changed during capture; preserving host directory");
    for (const auto& rel : files) {
        if (!same_bytes(source / rel, destination / rel))
            throw std::runtime_error("External file changed before removal");
        if (!fs::remove(source / rel)) throw std::runtime_error("External file could not be removed");
    }
    std::sort(directories.begin(), directories.end(), [](const Path& a, const Path& b) {
        return std::distance(a.begin(), a.end()) > std::distance(b.begin(), b.end());
    });
    for (const auto& rel : directories) {
        if (!fs::remove(source / rel)) throw std::runtime_error("External subdirectory is not empty or is locked");
    }
    // remove() only succeeds for an empty directory, so a concurrent writer
    // cannot cause us to recursively delete a new file.
    if (!fs::remove(source)) throw std::runtime_error("External directory is not empty or is locked");
}

static std::wstring timestamp_suffix() {
    SYSTEMTIME t; GetSystemTime(&t);
    wchar_t buffer[48];
    swprintf_s(buffer, L"%04u%02u%02u-%02u%02u%02u-%lu", t.wYear,t.wMonth,t.wDay,
             t.wHour,t.wMinute,t.wSecond,GetCurrentProcessId());
    return buffer;
}
// Microsoft documents REPARSE_DATA_BUFFER in the WDK's ntifs.h, which is NOT
// part of the ordinary user-mode Visual Studio C++ build environment.
// We only need the Windows-defined mount-point payload. Declare that exact wire
// layout here, using standard Win32 types provided by windows.h/winioctl.h.
// This avoids requiring the Windows Driver Kit or mixing kernel and user headers.
struct ObsMountPointReparseBuffer {
    ULONG ReparseTag;
    USHORT ReparseDataLength;
    USHORT Reserved;
    struct {
        USHORT SubstituteNameOffset;
        USHORT SubstituteNameLength;
        USHORT PrintNameOffset;
        USHORT PrintNameLength;
        WCHAR PathBuffer[1];
    } MountPointReparseBuffer;
};
constexpr size_t kObsReparseHeaderBytes = offsetof(ObsMountPointReparseBuffer, MountPointReparseBuffer);
constexpr size_t kObsMountPointPrefixBytes = offsetof(ObsMountPointReparseBuffer, MountPointReparseBuffer.PathBuffer);
static_assert(kObsReparseHeaderBytes == 8, "Unexpected reparse header layout");
static_assert(kObsMountPointPrefixBytes == 16, "Unexpected mount-point payload layout");
static_assert(sizeof(WCHAR) == 2, "Mount-point paths require UTF-16 WCHAR");

static bool make_junction(const Path& link, const Path& target) {
    // A directory junction is supported without elevation on writable NTFS volumes.
    // It keeps live OBS config in Data, unlike temporary App/config copies.
    if (!CreateDirectoryW(link.c_str(), nullptr)) return false;
    HANDLE handle = CreateFileW(link.c_str(), GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
                    FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, nullptr);
    if (handle == INVALID_HANDLE_VALUE) { RemoveDirectoryW(link.c_str()); return false; }
    std::wstring absolute = fs::absolute(target).wstring();
    const std::wstring substitute = L"\\??\\" + absolute;
    const std::wstring printed = absolute;
    // Both name lengths are USHORT in the filesystem wire format.
    if (substitute.size() * sizeof(WCHAR) > USHRT_MAX ||
        printed.size() * sizeof(WCHAR) > USHRT_MAX) {
        CloseHandle(handle);
        RemoveDirectoryW(link.c_str());
        return false;
    }
    const USHORT sublen = static_cast<USHORT>(substitute.size() * sizeof(WCHAR));
    const USHORT printlen = static_cast<USHORT>(printed.size() * sizeof(WCHAR));
    const size_t bytecount = kObsMountPointPrefixBytes + sublen + sizeof(WCHAR) + printlen + sizeof(WCHAR);
    // Microsoft's maximum reparse buffer is 16 KiB. Use a local bound so this
    // user-mode launcher never depends on optional WDK-only constants.
    constexpr size_t kObsMaxReparseBufferBytes = 16u * 1024u;
    // Reparse point buffers are capped at 16 KiB; reject oversize path data
    // instead of truncating the Win32 USHORT length fields.
    if (bytecount > kObsMaxReparseBufferBytes ||
        bytecount - kObsReparseHeaderBytes > USHRT_MAX) {
        CloseHandle(handle);
        RemoveDirectoryW(link.c_str());
        return false;
    }
    std::vector<BYTE> bytes(bytecount, 0);
    auto *reparse = reinterpret_cast<ObsMountPointReparseBuffer*>(bytes.data());
    reparse->ReparseTag = IO_REPARSE_TAG_MOUNT_POINT;
    reparse->ReparseDataLength = static_cast<USHORT>(bytecount - kObsReparseHeaderBytes);
    reparse->MountPointReparseBuffer.SubstituteNameOffset = 0;
    reparse->MountPointReparseBuffer.SubstituteNameLength = sublen;
    reparse->MountPointReparseBuffer.PrintNameOffset = sublen + sizeof(wchar_t);
    reparse->MountPointReparseBuffer.PrintNameLength = printlen;
    BYTE *b = reinterpret_cast<BYTE*>(reparse->MountPointReparseBuffer.PathBuffer);
    memcpy(b, substitute.c_str(), sublen);
    memcpy(b + sublen + sizeof(wchar_t), printed.c_str(), printlen);
    DWORD returned=0;
    BOOL success=DeviceIoControl(handle,FSCTL_SET_REPARSE_POINT,bytes.data(),
                                 (DWORD)bytes.size(),nullptr,0,&returned,nullptr);
    CloseHandle(handle);
    if (!success) RemoveDirectoryW(link.c_str());
    return !!success;
}
static bool starts_obs_name(std::wstring name) {
    name = lower(name);
    return name == L"obs-studio" || name == L"obs-studio-hook" ||
           name == L"obs-studio-updater" ||
           name.rfind(L"obs-studio-portable-",0)==0 || name.rfind(L"obs_portable_",0)==0;
}
struct ObservedRoot {
    Path base;
    std::wstring label;
    std::set<std::wstring> before;
};
static std::vector<ObservedRoot> snapshot_roots() {
    std::vector<ObservedRoot> result;
    for(const auto& root : std::vector<std::pair<const wchar_t*,const wchar_t*>>{
          {L"APPDATA",L"Roaming"},{L"LOCALAPPDATA",L"Local"},
          {L"PROGRAMDATA",L"ProgramData"},{L"TEMP",L"Temp"}}) {
        std::wstring value=env(root.first);
        if(value.empty() || !fs::is_directory(Path(value))) continue;
        ObservedRoot o{Path(value),root.second,{}};
        std::error_code ec;
        for(fs::directory_iterator it(o.base,fs::directory_options::skip_permission_denied,ec),end;
            it!=end && !ec; it.increment(ec)) {
            if(it->exists(ec)) o.before.insert(lower(it->path().filename().wstring()));
            ec.clear();
        }
        result.push_back(std::move(o));
    }
    return result;
}
static void capture_new_external(const std::vector<ObservedRoot>& roots,
                                 const Path& data, const Path& log) {
    const Path conflicts=data/L"RecoveryConflicts"/timestamp_suffix();
    for(const auto& o: roots) {
        std::error_code ec;
        for(fs::directory_iterator it(o.base,fs::directory_options::skip_permission_denied,ec),end;
            it!=end && !ec; it.increment(ec)) {
            if(!it->is_directory(ec)) { ec.clear(); continue; }
            const Path path=it->path();
            const std::wstring name=lower(path.filename().wstring());
            if(o.before.count(name) || !starts_obs_name(name) || is_reparse(path)) continue;
            try {
                Path dest=data/L"TraceGuard"/o.label/path.filename();
                safe_capture_and_remove(path,dest,conflicts/o.label/path.filename());
                std::wofstream manifest(data/L"TraceGuard"/L"relocation-manifest.tsv",std::ios::app);
                if(manifest) manifest << path.wstring() << L'\t' << dest.wstring() << L'\n';
                // Ownership comes from the before/after snapshot. A pre-existing
                // ProgramData hook folder always remains untouched.
                log_line(log,L"Captured newly created OBS-owned external directory: "+name);
            } catch(const std::exception&) {
                log_line(log,L"External location could not be fully relocated; leftovers remain for manual review: "+name);
            }
            ec.clear();
        }
    }
}
static bool other_obs_running(const Path& ownExe) {
    HANDLE snap=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);
    if(snap==INVALID_HANDLE_VALUE) return false;
    PROCESSENTRY32W pe{sizeof(pe)};
    bool found=false;
    if(Process32FirstW(snap,&pe)) do {
        if(_wcsicmp(pe.szExeFile,L"obs64.exe")!=0) continue;
        HANDLE p=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pe.th32ProcessID);
        if(!p) { found=true; break; } // uncertain ownership, be conservative
        std::wstring path(32768,L'\0'); DWORD n=(DWORD)path.size();
        bool good=!!QueryFullProcessImageNameW(p,0,path.data(),&n);
        CloseHandle(p);
        if(!good) { found=true; break; }
        path.resize(n);
        if(lower(path) != lower(ownExe.wstring())) { found=true; break; }
        found=true; break;
    } while(Process32NextW(snap,&pe));
    CloseHandle(snap);
    return found;
}
static std::wstring quote_arg(const std::wstring& s) {
    // Correct escaping for Windows CreateProcess argument parsing.
    std::wstring out=L"\""; size_t slash=0;
    for(wchar_t c:s) {
        if(c==L'\\') { ++slash; continue; }
        if(c==L'"') { out.append(slash*2+1,L'\\'); out+=L'"'; slash=0; continue; }
        out.append(slash,L'\\'); slash=0; out+=c;
    }
    out.append(slash*2,L'\\'); out+=L'"'; return out;
}
static int self_test_trace_guard(const Path& data, const Path& log) {
    const auto roots=snapshot_roots();
    std::wstring local=env(L"LOCALAPPDATA");
    if(local.empty()) throw std::runtime_error("LOCALAPPDATA unavailable");
    Path fixture=Path(local)/L"obs-studio-portable-fixture-test";
    if(fs::exists(fixture)) throw std::runtime_error("Trace fixture already exists; will not touch it");
    fs::create_directories(fixture/L"nested"/L"nonempty");
    fs::create_directories(fixture/L"totally-empty");
    fs::create_directories(fixture/L"empty-tree"/L"deep"/L"leaf");
    std::ofstream(fixture/L"created.txt") << "trace-file-contents\n";
    std::ofstream(fixture/L"nested"/L"nonempty"/L"nested.txt") << "nested\n";
    capture_new_external(roots,data,log);
    Path dest=data/L"TraceGuard"/L"Local"/fixture.filename();
    if(fs::exists(fixture) || !fs::is_regular_file(dest/L"created.txt") ||
       !fs::is_regular_file(dest/L"nested"/L"nonempty"/L"nested.txt") ||
       !fs::is_directory(dest/L"totally-empty") ||
       !fs::is_directory(dest/L"empty-tree"/L"deep"/L"leaf"))
        throw std::runtime_error("TraceGuard file/empty-directory capture assertion failed");
    return 0;
}
// Emulates the game-capture hook using a private ProgramData fixture only;
// never touches the runner's actual C:\ProgramData. A pre-existing host folder
// must survive unchanged, including when its name is obs-studio-hook.
static int self_test_programdata_hook(const Path& data, const Path& log) {
    const Path sandbox = data / L"_ProgramDataHookSelfTest";
    const Path programData = sandbox / L"ProgramData";
    const Path testData = sandbox / L"CapturedData";
    fs::create_directories(programData);
    fs::create_directories(testData);
    const std::wstring previous = env(L"PROGRAMDATA");
    if (!SetEnvironmentVariableW(L"PROGRAMDATA", programData.c_str()))
        throw std::runtime_error("Cannot set private ProgramData test root");
    try {
        const auto roots = snapshot_roots();
        const Path hook = programData / L"obs-studio-hook";
        if (fs::exists(hook)) throw std::runtime_error("Hook test host root already exists");
        fs::create_directories(hook / L"nested" / L"empty" / L"deep");
        fs::create_directories(hook / L"empty-only");
        std::ofstream(hook / L"graphics-hook64.dll", std::ios::binary) << "hook fixture";
        std::ofstream(hook / L"nested" / L"sample.txt", std::ios::binary) << "nested fixture";
        capture_new_external(roots, testData, log);
        const Path saved = testData / L"TraceGuard" / L"ProgramData" / L"obs-studio-hook";
        if (fs::exists(hook) || !fs::is_regular_file(saved / L"graphics-hook64.dll") ||
            !fs::is_regular_file(saved / L"nested" / L"sample.txt") ||
            !fs::is_directory(saved / L"nested" / L"empty" / L"deep") ||
            !fs::is_directory(saved / L"empty-only"))
            throw std::runtime_error("ProgramData hook capture did not preserve file and empty folder hierarchy");
        // A previously existing hook may belong to a conventional OBS install.
        fs::create_directories(hook);
        std::ofstream(hook / L"installed-obs-keep.txt") << "pre-existing host data";
        const auto preexisting = snapshot_roots();
        capture_new_external(preexisting, testData, log);
        if (!fs::is_regular_file(hook / L"installed-obs-keep.txt"))
            throw std::runtime_error("Pre-existing ProgramData hook must not be claimed");
        // A newly created, completely empty hook directory is also preserved.
        const Path secondRoot = sandbox / L"EmptyProgramData";
        fs::create_directories(secondRoot);
        if (!SetEnvironmentVariableW(L"PROGRAMDATA", secondRoot.c_str()))
            throw std::runtime_error("Cannot switch private ProgramData test root");
        const auto emptyRoots = snapshot_roots();
        const Path emptyHook = secondRoot / L"obs-studio-hook";
        fs::create_directories(emptyHook);
        fs::remove_all(saved); // Private disposable test Data only.
        capture_new_external(emptyRoots, testData, log);
        if (fs::exists(emptyHook) || !fs::is_directory(saved) || !fs::is_empty(saved))
            throw std::runtime_error("Empty ProgramData hook directory was not captured");
    } catch (...) {
        SetEnvironmentVariableW(L"PROGRAMDATA", previous.empty() ? nullptr : previous.c_str());
        throw;
    }
    SetEnvironmentVariableW(L"PROGRAMDATA", previous.empty() ? nullptr : previous.c_str());
    return 0;
}

// A headless Windows storage test that exercises the actual launcher junction
// and verified copy-back code without attempting to open OBS's Qt GUI.
// OBS's documented --version and --help commands are not available on Windows.
static int self_test_portable_storage(const Path& link, const Path& saved, const Path& data) {
    fs::create_directories(saved);
    if (is_reparse(link)) {
        if (!RemoveDirectoryW(link.c_str())) throw std::runtime_error("Cannot remove old test config junction");
    }
    const Path conflicts = data / L"RecoveryConflicts" / timestamp_suffix();
    if (fs::is_directory(link)) {
        safe_copy_tree(link, saved, conflicts);
        fs::remove_all(link);
    }
    const bool junction = make_junction(link, saved);
    if (!junction) {
        fs::create_directories(link);
        safe_copy_tree(saved, link, conflicts);
    }
    const Path relative = Path(L"obs-studio") / L"builder-storage-selftest.txt";
    fs::create_directories(link / L"obs-studio" / L"builder-empty-tree" / L"deep");
    {
        std::ofstream output(link / relative, std::ios::binary | std::ios::trunc);
        if (!output) throw std::runtime_error("Storage test could not create fixture");
        output << "test portable config persistence\n";
        if (!output) throw std::runtime_error("Storage test could not write fixture");
    }
    if (junction) {
        if (!same_bytes(link / relative, saved / relative))
            throw std::runtime_error("Storage test junction is not pointing to Data");
        if (!RemoveDirectoryW(link.c_str()))
            throw std::runtime_error("Storage test could not remove junction safely");
    } else {
        safe_copy_tree(link, saved, conflicts);
        fs::remove_all(link);
    }
    if (fs::exists(link) || !fs::is_regular_file(saved / relative) ||
        !fs::is_directory(saved / L"obs-studio" / L"builder-empty-tree" / L"deep"))
        throw std::runtime_error("Storage test did not preserve files and empty directory tree in Data");
    return 0;
}

static int launch(int argc,wchar_t** argv) {
    const Path root=executable_path().parent_path();
    const Path data=root/L"Data";
    const Path app=root/L"App"/L"OBSStudio";
    const Path target=app/L"bin"/L"64bit"/L"obs64.exe";
    const Path link=app/L"config";
    const Path saved=data/L"OBSConfig";
    const Path log=data/L"launcher.log";
    fs::create_directories(data);
    auto salt=std::hash<std::wstring>{}(lower(root.wstring()));
    const std::wstring mutexName=L"Local\\OBSStudioPortable-"+std::to_wstring(salt);
    HANDLE mutex=CreateMutexW(nullptr,TRUE,mutexName.c_str());
    if(!mutex || GetLastError()==ERROR_ALREADY_EXISTS) {
        if(mutex) CloseHandle(mutex);
        show_error(L"This portable OBS folder is already running. Close it before launching again.");
        return 10;
    }
    int result=0;
    try {
        if(argc>1 && std::wstring(argv[1])==L"--traceguard-selftest") {
            result=self_test_trace_guard(data,log);
        } else if(argc>1 && std::wstring(argv[1])==L"--programdata-hook-selftest") {
            result=self_test_programdata_hook(data,log);
        } else if(argc>1 && std::wstring(argv[1])==L"--storage-selftest") {
            result=self_test_portable_storage(link,saved,data);
        } else {
            if(!fs::is_regular_file(target)) throw std::runtime_error("OBS executable is missing");
            if(other_obs_running(target)) throw std::runtime_error("An OBS process is already running. Close OBS before portable startup to prevent profile conflicts");
            fs::create_directories(saved);
            // Recreate relocated junctions; remove link only, never follow into Data.
            if(is_reparse(link)) {
                if(!RemoveDirectoryW(link.c_str())) throw std::runtime_error("Cannot remove old config junction");
            }
            const Path conflicts=data/L"RecoveryConflicts"/timestamp_suffix();
            // Recover interrupted non-NTFS/copy fallback state BEFORE launching again.
            if(fs::is_directory(link)) {
                safe_copy_tree(link,saved,conflicts);
                // Remove only verified program-owned temporary config in App.
                fs::remove_all(link);
            }
            bool junction=make_junction(link,saved);
            if(!junction) {
                log_line(log,L"NTFS junction unavailable; using recoverable copy-back mode");
                fs::create_directories(link);
                safe_copy_tree(saved,link,conflicts);
            } else {
                log_line(log,L"OBS configuration directly redirected to Data via NTFS junction");
            }
            // Discover OBS-named external roots created during this instance. Existing roots
            // are excluded so a pre-existing installed OBS profile is never claimed.
            const auto observed=snapshot_roots();
            std::wstring command=quote_arg(target.wstring())+L" --portable --disable-updater";
            for(int i=1;i<argc;i++) {
                if(_wcsicmp(argv[i],L"--multi")==0 || _wcsicmp(argv[i],L"-m")==0) {
                    throw std::runtime_error("--multi is not supported: concurrent profile writes are unsafe");
                }
                command+=L" "+quote_arg(argv[i]);
            }
            STARTUPINFOW si{sizeof(si)}; PROCESS_INFORMATION pi{};
            std::vector<wchar_t> cmd(command.begin(),command.end()); cmd.push_back(0);
            bool launched=!!CreateProcessW(target.c_str(),cmd.data(),nullptr,nullptr,FALSE,0,nullptr,
                                          (app/L"bin"/L"64bit").c_str(),&si,&pi);
            if(!launched) throw std::runtime_error("Windows CreateProcess failed for OBS");
            CloseHandle(pi.hThread);
            WaitForSingleObject(pi.hProcess,INFINITE);
            DWORD exitCode=1;
            GetExitCodeProcess(pi.hProcess,&exitCode);
            CloseHandle(pi.hProcess);
            // OBS can restart itself via Qt detached process. Avoid touching data while it runs.
            // A bounded grace window catches common fast restarts.
            std::this_thread::sleep_for(std::chrono::milliseconds(1300));
            int iterations=0;
            while(other_obs_running(target) && iterations++ < 7200)
                std::this_thread::sleep_for(std::chrono::milliseconds(500));
            if(other_obs_running(target)) {
                log_line(log,L"OBS still running; deferred cleanup. Data junction stays valid");
                return 12;
            }
            if(!junction) {
                // Only remove an App-owned fallback tree once its full contents are verified in Data.
                safe_copy_tree(link,saved,data/L"RecoveryConflicts"/timestamp_suffix());
                fs::remove_all(link);
            } else {
                // IMPORTANT: do not leave a junction in App during upgrades. An installer
                // recursively replacing App must never risk following a link into Data.
                if(!RemoveDirectoryW(link.c_str()))
                    throw std::runtime_error("OBS finished but safe Data junction removal failed");
            }
            capture_new_external(observed,data,log);
            result=(int)exitCode;
        }
    } catch(const std::exception& e) {
        std::string what=e.what();
        log_line(log,L"Launcher encountered error (full details shown in dialog)");
        std::wstring wide(what.begin(),what.end());
        show_error(L"Portable launch/capture failed: "+wide+L"\nSee Data\\launcher.log. Nothing in an unrelated profile was deleted.");
        result=11;
    }
    ReleaseMutex(mutex); CloseHandle(mutex);
    return result;
}
int WINAPI wWinMain(HINSTANCE,HINSTANCE,LPWSTR,int) {
    int argc=0; LPWSTR *args=CommandLineToArgvW(GetCommandLineW(),&argc);
    if(!args) return 9;
    int result=launch(argc,args);
    LocalFree(args);
    return result;
}
