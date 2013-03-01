#The EVS Automator is the master ruby file which contains and executes the following EVS Automation Components:
#1) EVS Manifest Generator
#2) EVS Rate Check
#3) EVS Rate Validator
#4) EVS Command Generator

$:.unshift File.dirname($0) #Necessary for OCRA (ruby .exe packager) to load additional files from the same directory as the EVS Automator

@operations = { '1' => 'Generate EVS Files', '2' => 'Validate Rates', '3' => 'Generate the shell command to copy EVS files to target directory' }
@input = ''
@stillWorking = true

def prompt()
	puts "Enter the corresponding number for the operation you want to execute:"
	@operations.each do |key, value|
		puts "#{key}) #{value}"
	end
	print "> "
	@input = gets.chomp
	while (1..@operations.size).include?(@input.to_i) == false
		puts "#{@input} is not a valid selection!  Re-enter a valid selection:"
		print "> "
		@input = gets.chomp
	end
end

puts "Welcome to the EVS Automator!"
prompt()
while @stillWorking
	case @input
	when '1'
		puts "Selected 1 - #{@operations['1']}!"
		load "manGen.rb"
	when '2'
		puts "Selected 2 - #{@operations['2']}!"
		load "validateRates.rb"
	when '3'
		puts "Selected 3 - #{@operations['3']}!"
		load "commandGenerator.rb"
	end

	puts "Would you like to perform another operation? (y/n)"
	if gets.chomp.downcase == 'y'
		prompt()
	else
		puts "Exiting the EVS Automator!"
		@stillWorking = false
	end
end