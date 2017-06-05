# Release Notes
 
## 1.0.0 (2017-??-??)

### Extended [IO](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO) interface
* [#await_readable](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_readable-instance_method)
* [#await_writable](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_writable-instance_method)
* [#concurrently_read](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_read-instance_method)
* [#concurrently_write](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_write-instance_method)

### Extended [Kernel](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel) interface
* [#concurrently](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrently-instance_method)
* [#concurrent_proc](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrent_proc-instance_method)
* [#wait](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#wait-instance_method)
* [#await_resume!](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#await_resume!-instance_method)

### Added (Root) Evaluation ([Concurrently::Evaluation](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation))
* [.current](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation#current-class_method)
* [#waiting?](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation#waiting%3F-instance_method)
* [#resume!](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation#resume!-instance_method)
 
### Added Concurrent Proc ([Concurrently::Proc](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc))
* [#call, #[]](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call-instance_method)
* [#call_nonblock](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_nonblock-instance_method)
* [#call_detached](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_detached-instance_method)
* [#call_and_forget](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_and_forget-instance_method)
 
### Added Proc Evaluation ([Concurrently::Proc::Evaluation](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation))
* [#await_result](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#await_result-instance_method)
* [#conclude_to](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#conclude_to-instance_method)
* [#concluded?](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#concluded%3F-instance_method)
* [#data](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#data-instance_method)

### Added Event Loop ([Concurrently::EventLoop](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop))
* [.current](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop#current-class_method)
* [#lifetime](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop#lifetime-instance_method)
* [#reinitialize!](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop#reinitialize!-instance_method)

### Added Errors
* [Concurrently::Error](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Error)
* [Concurrently::Evaluation::Error](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation/Error)
* [Concurrently::Evaluation::TimeoutError](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation/TimeoutError)


## 0.0.0 (~13.8 billion years ago)