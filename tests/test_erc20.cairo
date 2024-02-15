use starknet::contract_address_const;

use tests::utils::{DEPLOYER, ACCOUNT1, ETH_SUPPLY, E18};
use nogame::token::erc20::erc20::{ERC20};
use openzeppelin::token::erc20::interface::{
    IERC20CamelDispatcher, IERC20CamelDispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait
};

use snforge_std::{declare, ContractClassTrait, start_prank,  CheatTarget};

#[test]
fn test_erc20_name() {
    let (erc20, erc20_meta) = deploy();

    assert(erc20_meta.name() == 'ether', 'name() failed');
}

#[test]
fn test_erc20_total_supply() {
    let (erc20, erc20_meta) = deploy();

    assert(erc20.totalSupply() == ETH_SUPPLY.into(), 'total supply failed');
}

#[test]
fn test_erc20_balance_of() {
    let (erc20, erc20_meta) = deploy();

    assert(erc20.balanceOf(DEPLOYER()) == ETH_SUPPLY.into(), 'balance_of failed');
}

#[test]
fn test_erc20_transfer() {
    let (erc20, erc20_meta) = deploy();

    start_prank(CheatTarget::One(erc20.contract_address), DEPLOYER());
    assert(erc20.transfer(ACCOUNT1(), E18.into()) == true, 'transfer failed');
}

#[test]
fn test_erc20_approve() {
    let (erc20, erc20_meta) = deploy();

    start_prank(CheatTarget::One(erc20.contract_address), DEPLOYER());
    erc20.transfer(ACCOUNT1(), E18.into());

    start_prank(CheatTarget::One(erc20.contract_address), ACCOUNT1());
    assert(erc20.approve(DEPLOYER(), 1_000_000) == true, 'approve failed')
}

#[test]
fn test_erc20_allowance() {
    let (erc20, erc20_meta) = deploy();

    start_prank(CheatTarget::One(erc20.contract_address), DEPLOYER());
    erc20.transfer(ACCOUNT1(), E18.into());

    start_prank(CheatTarget::One(erc20.contract_address), ACCOUNT1());
    erc20.approve(DEPLOYER(), 1_000_000);
    assert(erc20.allowance(ACCOUNT1(), DEPLOYER()) == 1_000_000, 'allowance failed');
}

fn deploy() -> (IERC20CamelDispatcher, IERC20MetadataDispatcher) {
    let contract = declare('ERC20');
    let calldata: Array<felt252> = array!['ether', 'ETH', ETH_SUPPLY, 0, DEPLOYER().into()];
    let contract_address = contract.deploy(@calldata).unwrap();
    return (
        IERC20CamelDispatcher { contract_address }, IERC20MetadataDispatcher { contract_address }
    );
}
