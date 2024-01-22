.PHONY: test

install:
	npm install --verbos
	
clean:
	rm -fr cache artifacts typechain-types

compile:
	npx hardhat compile

test:
	npx hardhat test

