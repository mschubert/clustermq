# Build against precompiled zeromq libs.
if(!file.exists("../windows/zeromq-4.2.1/include/zmq.h")){
  if(getRversion() < "3.3.0") setInternet2()
  download.file("https://github.com/rwinlib/zeromq/archive/v4.2.1.zip", "lib.zip", quiet = TRUE)
  dir.create("../windows", showWarnings = FALSE)
  unzip("lib.zip", exdir = "../windows")
  unlink("lib.zip")
}
