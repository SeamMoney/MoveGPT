Simple ToDo list for Move Lang

Publish using
* aptos move publish --named-addresses journeyman=default --assume-yes

Run using
* aptos move run --function-id 'default::ToDo4::add_todos' --args 'string:Write gratefulness notes' --assume-yes 
* aptos move run --function-id 'default::ToDo4::add_todos' --args 'string:Sleep after writing notes' --assume-yes

View using
* aptos move view --function-id 'default::ToDo4::get_last_todo' --args 'address:default'
* aptos move view --function-id 'default::ToDo4::get_all_todos' --args 'address:default' 


Enjoy!  
Chee-Wee Chua,  
20 May 2023.  
