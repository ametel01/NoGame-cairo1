use starknet::{ContractAddress, class_hash::ClassHash};
use nogame::libraries::types::{
    DefencesCost, DefencesLevels, EnergyCost, ERC20s, CompoundsCost, CompoundsLevels, ShipsLevels,
    ShipsCost, TechLevels, TechsCost, Tokens, PlanetPosition, Cargo, Debris, Fleet, Mission,
    HostileMission, UpgradeType, BuildType
};

#[starknet::interface]
trait INoGame<TState> {
    fn initializer(
        ref self: TState,
        erc721: ContractAddress,
        steel: ContractAddress,
        quartz: ContractAddress,
        tritium: ContractAddress,
        eth: ContractAddress,
        owner: ContractAddress,
        uni_speed: u128,
        token_price: u128,
        is_testnet: bool
    );
    // Upgradable
    fn upgrade(ref self: TState, impl_hash: ClassHash);
    // Write functions
    fn generate_mint_key(ref self: TState, secret: felt252);
    fn get_mint_key(self: @TState, account: ContractAddress) -> felt252;
    fn generate_planet(ref self: TState);
    fn collect_resources(ref self: TState);
    fn process_compound_upgrade(ref self: TState, component: UpgradeType, quantity: u8);
    fn process_tech_upgrade(ref self: TState, component: UpgradeType, quantity: u8);
    fn process_ship_build(ref self: TState, component: BuildType, quantity: u32);
    fn process_defence_build(ref self: TState, component: BuildType, quantity: u32);
    // Fleet functions
    fn send_fleet(
        ref self: TState, f: Fleet, destination: PlanetPosition, is_debris_collection: bool
    );
    fn attack_planet(ref self: TState, mission_id: usize);
    fn recall_fleet(ref self: TState, mission_id: usize);
    fn collect_debris(ref self: TState, mission_id: usize);
    // View functions
    fn get_token_addresses(self: @TState) -> Tokens;
    fn get_current_planet_price(self: @TState) -> u128;
    fn get_number_of_planets(self: @TState) -> u16;
    fn get_generated_planets_positions(self: @TState) -> Array<PlanetPosition>;
    fn get_planet_position(self: @TState, planet_id: u16) -> PlanetPosition;
    fn get_position_slot_occupant(self: @TState, position: PlanetPosition) -> u16;
    fn get_debris_field(self: @TState, planet_id: u16) -> Debris;
    fn get_spendable_resources(self: @TState, planet_id: u16) -> ERC20s;
    fn get_collectible_resources(self: @TState, planet_id: u16) -> ERC20s;
    fn get_planet_points(self: @TState, planet_id: u16) -> u128;
    fn get_ships_levels(self: @TState, planet_id: u16) -> Fleet;
    fn get_celestia_available(self: @TState, planet_id: u16) -> u32;
    fn get_defences_levels(self: @TState, planet_id: u16) -> DefencesLevels;
    fn is_noob_protected(self: @TState, planet1_id: u16, planet2_id: u16) -> bool;
    fn get_mission_details(self: @TState, planet_id: u16, mission_id: usize) -> Mission;
    fn get_hostile_missions(self: @TState, planet_id: u16) -> Array<HostileMission>;
    fn get_active_missions(self: @TState, planet_id: u16) -> Array<Mission>;
}

