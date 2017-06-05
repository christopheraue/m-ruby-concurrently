# Changes
 
## 1.0.0 (2017-??-??)

### Extended {IO} interface
* {IO#await_readable #await_readable}
* {IO#await_writable #await_writable}
* {IO#concurrently_read #concurrently_read}
* {IO#concurrently_write #concurrently_write}

### Extended {Kernel} interface
* {Kernel#concurrently #concurrently}
* {Kernel#concurrent_proc #concurrent_proc}
* {Kernel#wait #wait}
* {Kernel#await_resume! #await_resume!}

### Added (Root) Evaluation ({Concurrently::Evaluation})
* {Concurrently::Evaluation.current .current}
* {Concurrently::Evaluation#waiting? #waiting?}
* {Concurrently::Evaluation#resume! #resume!}
 
### Added Concurrent Proc ({Concurrently::Proc})
* {Concurrently::Proc#call #call}, {Concurrently::Proc#[] #[]}
* {Concurrently::Proc#call_nonblock #call_nonblock}
* {Concurrently::Proc#call_detached #call_detached}
* {Concurrently::Proc#call_and_forget #call_and_forget}
 
### Added Proc Evaluation ({Concurrently::Proc::Evaluation})
* {Concurrently::Proc::Evaluation#concluded? #concluded?}
* {Concurrently::Proc::Evaluation#conclude_to #conclude_to}
* {Concurrently::Proc::Evaluation#await_result #await_result}
* {Concurrently::Proc::Evaluation#data #data}

### Added Event Loop ({Concurrently::EventLoop})
* {Concurrently::EventLoop.current .current}
* {Concurrently::EventLoop#lifetime #lifetime}
* {Concurrently::EventLoop#reinitialize! #reinitialize!}

### Added Errors
* {Concurrently::Error}
* {Concurrently::Evaluation::Error}
* {Concurrently::Evaluation::TimeoutError}


## 0.0.0 (~13.8 billion years ago)