use starknet::ContractAddress;

const E18: u128 = 1000000000000000000;

// #[derive(Copy, Drop, Serde)]
// struct Cost {
//     steel: u128,
//     quartz: u128,
//     tritium: u128,
// }
#[derive(Copy, Drop, Serde)]
struct Cost {
    steel: u128,
    quartz: u128,
    tritium: u128,
}

#[derive(Drop, Serde)]
struct Tokens {
    steel: ContractAddress,
    quartz: ContractAddress,
    tritium: ContractAddress,
}

#[derive(Drop, Serde)]
struct Resources {
    steel: u128,
    quartz: u128,
    tritium: u128,
    energy: u128
}

#[derive(Drop, Serde)]
struct ERC20s {
    steel: u128,
    quartz: u128,
    tritium: u128,
}

#[derive(Drop, Serde)]
struct MinesCost {
    steel: Cost,
    quartz: Cost,
    tritium: Cost,
    solar: Cost,
}

#[derive(Drop, Serde)]
struct MinesLevels {
    steel: u128,
    quartz: u128,
    tritium: u128,
    energy: u128
}

struct Compounds {}

#[derive(Copy, Destruct, Drop)]
struct Techs {
    energy_innovation: u128,
    digital_systems: u128,
    beam_technology: u128,
    armour_innovation: u128,
    ion_systems: u128,
    plasma_engineering: u128,
    stellar_physics: u128,
    arms_development: u128,
    shield_tech: u128,
    spacetime_warp: u128,
    combustive_engine: u128,
    thrust_propulsion: u128,
    warp_drive: u128,
}


struct Defences {
    blaster: u128,
    beam: u128,
    astral_launcher: u128,
    plasma_beam: u128
}

