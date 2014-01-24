time_tracker
============


## Install
Clone or fork the repo.

Navigate to the time_tracker directory and run:

    perl time_tracker.pl

If you get an error similiar to this:

> Can't locate object method "pretty" via package "Time::Seconds"


Install the missing module using 'cpan \<module name\>'
  
  For example, time tracker requires the module Time::Seconds. To install the module run the command 
  
    cpan Time::Seconds  
  

## Usage
For a list of options and help run

    perl time_tracker.pl -h
