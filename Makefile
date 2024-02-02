.PHONY: test coverage

install:
	npm install --verbos
	
clean:
	rm -fr cache artifacts typechain-types

compile: clean
	npx hardhat compile

test:
	npx hardhat test

coverage:
	rm -fr coverage && npx hardhat coverage

