.PHONY: test coverage

install:
	npm install --verbos
	
clean:
	rm -fr cache artifacts typechain-types

compile: clean
	npx hardhat compile

upgrade:
	npx hardhat run scripts/upgrade-business.ts --network arb

verify:
	npx hardhat verify 0x01f2F14808f11B91f5643ae83358fF891eEB76a3 --network arb

test:
	npx hardhat test

coverage:
	rm -fr coverage && npx hardhat coverage

