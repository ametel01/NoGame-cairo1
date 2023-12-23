// TODOS: 

#[starknet::contract]
mod NoGame {
    use traits::DivRem;
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
        SyscallResultTrait, class_hash::ClassHash
    };
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use cubit::f128::types::fixed::{Fixed, FixedTrait, ONE_u128 as ONE};

    use nogame::game::interface::INoGame;
    use nogame::libraries::types::{
        ETH_ADDRESS, BANK_ADDRESS, E18, DefencesCost, DefencesLevels, EnergyCost, ERC20s, erc20_mul,
        CompoundsCost, CompoundsLevels, ShipsLevels, ShipsCost, TechLevels, TechsCost, Tokens,
        PlanetPosition, Debris, Mission, HostileMission, Fleet, MAX_NUMBER_OF_PLANETS, _0_05, PRICE,
        DAY, HOUR, Names
    };
    use nogame::libraries::compounds::{Compounds, CompoundCost, Consumption, Production};
    use nogame::libraries::defences::Defences;
    use nogame::libraries::dockyard::Dockyard;
    use nogame::libraries::fleet;
    use nogame::libraries::research::Lab;
    use nogame::libraries::positions;
    use nogame::token::erc20::interface::{IERC20NoGameDispatcher, IERC20NoGameDispatcherTrait};
    use nogame::token::erc721::interface::{IERC721NoGameDispatcherTrait, IERC721NoGameDispatcher};

    use nogame::libraries::auction::{LinearVRGDA, LinearVRGDATrait};

    #[storage]
    struct Storage {
        initialized: bool,
        receiver: ContractAddress,
        version: u8,
        token_price: u128,
        uni_speed: u128,
        // General.
        number_of_planets: u16,
        planet_position: LegacyMap::<u16, PlanetPosition>,
        position_to_planet: LegacyMap::<PlanetPosition, u16>,
        planet_debris_field: LegacyMap::<u16, Debris>,
        universe_start_time: u64,
        resources_spent: LegacyMap::<u16, u128>,
        last_active: LegacyMap::<u16, u64>,
        // Tokens.
        erc721: IERC721NoGameDispatcher,
        steel: IERC20NoGameDispatcher,
        quartz: IERC20NoGameDispatcher,
        tritium: IERC20NoGameDispatcher,
        ETH: IERC20CamelDispatcher,
        // Infrastructures.
        steel_mine_level: LegacyMap::<u16, u8>,
        quartz_mine_level: LegacyMap::<u16, u8>,
        tritium_mine_level: LegacyMap::<u16, u8>,
        energy_plant_level: LegacyMap::<u16, u8>,
        dockyard_level: LegacyMap::<u16, u8>,
        lab_level: LegacyMap::<u16, u8>,
        resources_timer: LegacyMap::<u16, u64>,
        // Technologies
        energy_innovation_level: LegacyMap::<u16, u8>,
        digital_systems_level: LegacyMap::<u16, u8>,
        beam_technology_level: LegacyMap::<u16, u8>,
        armour_innovation_level: LegacyMap::<u16, u8>,
        ion_systems_level: LegacyMap::<u16, u8>,
        plasma_engineering_level: LegacyMap::<u16, u8>,
        stellar_physics_level: LegacyMap::<u16, u8>,
        weapons_development_level: LegacyMap::<u16, u8>,
        shield_tech_level: LegacyMap::<u16, u8>,
        spacetime_warp_level: LegacyMap::<u16, u8>,
        combustive_engine_level: LegacyMap::<u16, u8>,
        thrust_propulsion_level: LegacyMap::<u16, u8>,
        warp_drive_level: LegacyMap::<u16, u8>,
        // Ships
        carrier_available: LegacyMap::<u16, u32>,
        scraper_available: LegacyMap::<u16, u32>,
        celestia_available: LegacyMap::<u16, u32>,
        sparrow_available: LegacyMap::<u16, u32>,
        frigate_available: LegacyMap::<u16, u32>,
        armade_available: LegacyMap::<u16, u32>,
        // Defences
        blaster_available: LegacyMap::<u16, u32>,
        beam_available: LegacyMap::<u16, u32>,
        astral_available: LegacyMap::<u16, u32>,
        plasma_available: LegacyMap::<u16, u32>,
        // Fleet
        active_missions: LegacyMap::<(u16, u32), Mission>,
        active_missions_len: LegacyMap<u16, usize>,
        hostile_missions: LegacyMap<(u16, u32), HostileMission>,
        hostile_missions_len: LegacyMap<u16, usize>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PlanetGenerated: PlanetGenerated,
        CompoundSpent: CompoundSpent,
        TechSpent: TechSpent,
        FleetSpent: FleetSpent,
        DefenceSpent: DefenceSpent,
        FleetSent: FleetSent,
        BattleReport: BattleReport,
        DebrisCollected: DebrisCollected,
        Upgraded: Upgraded,
    }

    #[derive(Drop, starknet::Event)]
    struct PlanetGenerated {
        id: u16,
        position: PlanetPosition,
        account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CompoundSpent {
        planet_id: u16,
        compound_name: felt252,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct TechSpent {
        planet_id: u16,
        tech_name: felt252,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct FleetSpent {
        planet_id: u16,
        ship_name: felt252,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct DefenceSpent {
        planet_id: u16,
        defence_name: felt252,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }

    #[derive(Drop, starknet::Event)]
    struct FleetSent {
        time: u64,
        origin: u16,
        destination: u16,
        mission_type: felt252,
    }


    #[derive(Drop, starknet::Event)]
    struct BattleReport {
        time: u64,
        attacker: u16,
        attacker_position: PlanetPosition,
        attacker_initial_fleet: Fleet,
        attacker_fleet_loss: Fleet,
        defender: u16,
        defender_position: PlanetPosition,
        defender_initial_fleet: Fleet,
        defender_fleet_loss: Fleet,
        initial_defences: DefencesLevels,
        defences_loss: DefencesLevels,
        loot: ERC20s,
        debris: Debris,
    }

    #[derive(Drop, starknet::Event)]
    struct DebrisCollected {
        time: u64,
        debris_field_id: u16,
        amount: Debris,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.universe_start_time.write(get_block_timestamp());
    }

    #[external(v0)]
    impl NoGame of INoGame<ContractState> {
        fn initializer(
            ref self: ContractState,
            erc721: ContractAddress,
            steel: ContractAddress,
            quartz: ContractAddress,
            tritium: ContractAddress,
            // rand: ContractAddress,
            eth: ContractAddress,
            receiver: ContractAddress,
            uni_speed: u128,
            token_price: u128,
        ) {
            // NOTE: uncomment the following after testing with katana.
            assert(!self.initialized.read(), 'already initialized');
            self.erc721.write(IERC721NoGameDispatcher { contract_address: erc721 });
            self.steel.write(IERC20NoGameDispatcher { contract_address: steel });
            self.quartz.write(IERC20NoGameDispatcher { contract_address: quartz });
            self.tritium.write(IERC20NoGameDispatcher { contract_address: tritium });
            self.ETH.write(IERC20CamelDispatcher { contract_address: eth });
            self.receiver.write(receiver);
            self.uni_speed.write(uni_speed);
            self.initialized.write(true);
            self.token_price.write(token_price);
        }

        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(impl_hash).unwrap_syscall();
            self.version.write(self.version.read() + 1);
            self.emit(Event::Upgraded(Upgraded { implementation: impl_hash }))
        }

        fn version(self: @ContractState) -> u8 {
            self.version.read()
        }

        /////////////////////////////////////////////////////////////////////
        //                         Planet Functions                                
        /////////////////////////////////////////////////////////////////////
        fn generate_planet(ref self: ContractState) {
            let caller = get_caller_address();
            let time_elapsed = (get_block_timestamp() - self.universe_start_time.read()) / DAY;
            let price: u256 = self.get_planet_price(time_elapsed).into();
            self.ETH.read().transferFrom(caller, self.receiver.read(), price);
            let number_of_planets = self.number_of_planets.read();
            assert(number_of_planets != MAX_NUMBER_OF_PLANETS, 'max number of planets');
            let token_id = number_of_planets + 1;
            let position = positions::get_planet_position(token_id);
            self.erc721.read().mint(caller, token_id.into());
            self.planet_position.write(token_id, position);
            self.position_to_planet.write(position, token_id);
            self.number_of_planets.write(number_of_planets + 1);
            self.receive_resources_erc20(caller, ERC20s { steel: 500, quartz: 300, tritium: 100 });
            self.resources_timer.write(token_id, get_block_timestamp());
            self
                .emit(
                    Event::PlanetGenerated(
                        PlanetGenerated { id: token_id, position, account: caller }
                    )
                );
        }

        fn collect_resources(ref self: ContractState) {
            self._collect_resources(get_caller_address());
        }

        /////////////////////////////////////////////////////////////////////
        //                         Mines Functions                                
        /////////////////////////////////////////////////////////////////////
        fn steel_mine_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let current_level = self.steel_mine_level.read(planet_id);
            let cost: ERC20s = CompoundCost::steel(current_level, quantity);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self
                .steel_mine_level
                .write(planet_id, current_level + quantity.try_into().expect('u32 into u8 failed'));
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .emit(
                    Event::CompoundSpent(
                        CompoundSpent {
                            planet_id: planet_id, compound_name: Names::STEEL, spent: cost
                        }
                    )
                )
        }
        fn quartz_mine_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let current_level = self.quartz_mine_level.read(planet_id);
            let cost: ERC20s = CompoundCost::quartz(current_level, quantity);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self
                .quartz_mine_level
                .write(planet_id, current_level + quantity.try_into().expect('u32 into u8 failed'));
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .emit(
                    Event::CompoundSpent(
                        CompoundSpent {
                            planet_id: planet_id, compound_name: Names::QUARTZ, spent: cost
                        }
                    )
                )
        }
        fn tritium_mine_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let current_level = self.tritium_mine_level.read(planet_id);
            let cost: ERC20s = CompoundCost::tritium(current_level, quantity);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self
                .tritium_mine_level
                .write(planet_id, current_level + quantity.try_into().expect('u32 into u8 failed'));
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .emit(
                    Event::CompoundSpent(
                        CompoundSpent {
                            planet_id: planet_id, compound_name: Names::TRITIUM, spent: cost
                        }
                    )
                )
        }
        fn energy_plant_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let current_level = self.energy_plant_level.read(planet_id);
            let cost: ERC20s = CompoundCost::energy(current_level, quantity);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self
                .energy_plant_level
                .write(planet_id, current_level + quantity.try_into().expect('u32 into u8 failed'));
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .emit(
                    Event::CompoundSpent(
                        CompoundSpent {
                            planet_id: planet_id, compound_name: Names::ENERGY_PLANT, spent: cost
                        }
                    )
                )
        }

        fn dockyard_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let current_level = self.dockyard_level.read(planet_id);
            let cost: ERC20s = CompoundCost::dockyard(current_level, quantity);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self
                .dockyard_level
                .write(planet_id, current_level + quantity.try_into().expect('u32 into u8 failed'));
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .emit(
                    Event::CompoundSpent(
                        CompoundSpent {
                            planet_id: planet_id, compound_name: Names::DOCKYARD, spent: cost
                        }
                    )
                )
        }
        fn lab_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let current_level = self.lab_level.read(planet_id);
            let cost: ERC20s = CompoundCost::lab(current_level, quantity);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self
                .lab_level
                .write(planet_id, current_level + quantity.try_into().expect('u32 into u8 failed'));
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .emit(
                    Event::CompoundSpent(
                        CompoundSpent {
                            planet_id: planet_id, compound_name: Names::LAB, spent: cost
                        }
                    )
                )
        }

        /////////////////////////////////////////////////////////////////////
        //                         Research Functions                                
        /////////////////////////////////////////////////////////////////////
        fn energy_innovation_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::energy_innovation_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().energy;
            let cost = Lab::get_tech_cost(techs.energy, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .energy_innovation_level
                .write(planet_id, techs.energy + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent {
                            planet_id: planet_id, tech_name: Names::ENERGY_TECH, spent: cost
                        }
                    )
                )
        }
        fn digital_systems_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::digital_systems_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().digital;
            let cost = Lab::get_tech_cost(techs.digital, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .digital_systems_level
                .write(planet_id, techs.digital + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::DIGITAL, spent: cost }
                    )
                )
        }
        fn beam_technology_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::beam_technology_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().beam;
            let cost = Lab::get_tech_cost(techs.beam, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .beam_technology_level
                .write(planet_id, techs.beam + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::BEAM_TECH, spent: cost }
                    )
                )
        }
        fn armour_innovation_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::armour_innovation_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().armour;
            let cost = Lab::get_tech_cost(techs.armour, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .armour_innovation_level
                .write(planet_id, techs.armour + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::ARMOUR, spent: cost }
                    )
                )
        }
        fn ion_systems_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::ion_systems_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().ion;
            let cost = Lab::get_tech_cost(techs.ion, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .ion_systems_level
                .write(planet_id, techs.ion + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::ION, spent: cost }
                    )
                )
        }
        fn plasma_engineering_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::plasma_engineering_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().plasma;
            let cost = Lab::get_tech_cost(techs.plasma, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .plasma_engineering_level
                .write(planet_id, techs.plasma + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent {
                            planet_id: planet_id, tech_name: Names::PLASMA_TECH, spent: cost
                        }
                    )
                )
        }

        fn weapons_development_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::weapons_development_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().weapons;
            let cost = Lab::get_tech_cost(techs.weapons, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .weapons_development_level
                .write(planet_id, techs.weapons + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::WEAPONS, spent: cost }
                    )
                )
        }
        fn shield_tech_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::shield_tech_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().shield;
            let cost = Lab::get_tech_cost(techs.shield, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .shield_tech_level
                .write(planet_id, techs.shield + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::SHIELD, spent: cost }
                    )
                )
        }
        fn spacetime_warp_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::spacetime_warp_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().spacetime;
            let cost = Lab::get_tech_cost(techs.spacetime, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .spacetime_warp_level
                .write(
                    planet_id, techs.spacetime + quantity.try_into().expect('u32 into u8 failed')
                );
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::SPACETIME, spent: cost }
                    )
                )
        }
        fn combustive_engine_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::combustive_engine_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().combustion;
            let cost = Lab::get_tech_cost(techs.combustion, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .combustive_engine_level
                .write(
                    planet_id, techs.combustion + quantity.try_into().expect('u32 into u8 failed')
                );
            self
                .emit(
                    Event::TechSpent(
                        TechSpent {
                            planet_id: planet_id, tech_name: Names::COMBUSTION, spent: cost
                        }
                    )
                )
        }
        fn thrust_propulsion_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::thrust_propulsion_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().thrust;
            let cost = Lab::get_tech_cost(techs.thrust, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .thrust_propulsion_level
                .write(planet_id, techs.thrust + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::THRUST, spent: cost }
                    )
                )
        }
        fn warp_drive_upgrade(ref self: ContractState, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let lab_level = self.lab_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Lab::warp_drive_requirements_check(lab_level, techs);
            let base_cost: ERC20s = Lab::base_tech_costs().warp;
            let cost = Lab::get_tech_cost(techs.warp, quantity, base_cost);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .warp_drive_level
                .write(planet_id, techs.warp + quantity.try_into().expect('u32 into u8 failed'));
            self
                .emit(
                    Event::TechSpent(
                        TechSpent { planet_id: planet_id, tech_name: Names::WARP, spent: cost }
                    )
                )
        }

        /////////////////////////////////////////////////////////////////////
        //                         Dockyard Functions                                
        /////////////////////////////////////////////////////////////////////
        fn carrier_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Dockyard::carrier_requirements_check(dockyard_level, techs);
            let cost = Dockyard::get_ships_cost(quantity, NoGame::get_ships_cost(@self).carrier);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .carrier_available
                .write(planet_id, self.carrier_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::FleetSpent(
                        FleetSpent { planet_id: planet_id, ship_name: Names::CARRIER, spent: cost }
                    )
                )
        }
        fn scraper_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Dockyard::scraper_requirements_check(dockyard_level, techs);
            let cost = Dockyard::get_ships_cost(quantity, NoGame::get_ships_cost(@self).scraper);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .scraper_available
                .write(planet_id, self.scraper_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::FleetSpent(
                        FleetSpent { planet_id: planet_id, ship_name: Names::SCRAPER, spent: cost }
                    )
                )
        }
        fn celestia_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Dockyard::celestia_requirements_check(dockyard_level, techs);
            let cost = Dockyard::get_ships_cost(quantity, NoGame::get_ships_cost(@self).celestia);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .celestia_available
                .write(planet_id, self.celestia_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::FleetSpent(
                        FleetSpent { planet_id: planet_id, ship_name: Names::CELESTIA, spent: cost }
                    )
                )
        }
        fn sparrow_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Dockyard::sparrow_requirements_check(dockyard_level, techs);
            let cost = Dockyard::get_ships_cost(quantity, NoGame::get_ships_cost(@self).sparrow);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .sparrow_available
                .write(planet_id, self.sparrow_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::FleetSpent(
                        FleetSpent { planet_id: planet_id, ship_name: Names::SPARROW, spent: cost }
                    )
                )
        }
        fn frigate_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Dockyard::frigate_requirements_check(dockyard_level, techs);
            let cost = Dockyard::get_ships_cost(quantity, NoGame::get_ships_cost(@self).frigate);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .frigate_available
                .write(planet_id, self.frigate_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::FleetSpent(
                        FleetSpent { planet_id: planet_id, ship_name: Names::FRIGATE, spent: cost }
                    )
                )
        }
        fn armade_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Dockyard::armade_requirements_check(dockyard_level, techs);
            let cost = Dockyard::get_ships_cost(quantity, NoGame::get_ships_cost(@self).armade);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .armade_available
                .write(planet_id, self.armade_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::FleetSpent(
                        FleetSpent { planet_id: planet_id, ship_name: Names::ARMADE, spent: cost }
                    )
                )
        }

        /////////////////////////////////////////////////////////////////////
        //                         Defences Functions                                
        /////////////////////////////////////////////////////////////////////
        fn blaster_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Defences::blaster_requirements_check(dockyard_level, techs);
            let cost = Defences::get_defences_cost(quantity, 2000, 0, 0);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .blaster_available
                .write(planet_id, self.blaster_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::DefenceSpent(
                        DefenceSpent {
                            planet_id: planet_id, defence_name: Names::BLASTER, spent: cost
                        }
                    )
                )
        }
        fn beam_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Defences::beam_requirements_check(dockyard_level, techs);
            let cost = Defences::get_defences_cost(quantity, 6000, 2000, 0);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self.beam_available.write(planet_id, self.beam_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::DefenceSpent(
                        DefenceSpent {
                            planet_id: planet_id, defence_name: Names::BEAM, spent: cost
                        }
                    )
                )
        }
        fn astral_launcher_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Defences::astral_launcher_requirements_check(dockyard_level, techs);
            let cost = Defences::get_defences_cost(quantity, 20000, 15000, 2000);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .astral_available
                .write(planet_id, self.astral_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::DefenceSpent(
                        DefenceSpent {
                            planet_id: planet_id, defence_name: Names::ASTRAL, spent: cost
                        }
                    )
                )
        }
        fn plasma_projector_build(ref self: ContractState, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.dockyard_level.read(planet_id);
            let techs = self.get_tech_levels(planet_id);
            Defences::plasma_beam_requirements_check(dockyard_level, techs);
            let cost = Defences::get_defences_cost(quantity, 50000, 50000, 30000);
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);
            self.update_planet_points(planet_id, cost);
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .plasma_available
                .write(planet_id, self.plasma_available.read(planet_id) + quantity);
            self
                .emit(
                    Event::DefenceSpent(
                        DefenceSpent {
                            planet_id: planet_id, defence_name: Names::PLASMA, spent: cost
                        }
                    )
                )
        }

        /////////////////////////////////////////////////////////////////////
        //                         Fleet Functions                                
        /////////////////////////////////////////////////////////////////////
        fn send_fleet(
            ref self: ContractState,
            f: Fleet,
            destination: PlanetPosition,
            is_debris_collection: bool
        ) {
            let destination_id = self.position_to_planet.read(destination);
            assert(!destination_id.is_zero(), 'no planet at destination');
            let caller = get_caller_address();
            let planet_id = self.get_owned_planet(caller);

            if is_debris_collection {
                assert(
                    !self.planet_debris_field.read(destination_id).is_zero(), 'empty debris fiels'
                );
                assert(f.scraper >= 1, 'no scrapers for collection');
                assert(
                    f.carrier.is_zero()
                        && f.sparrow.is_zero()
                        && f.frigate.is_zero() & f.armade.is_zero(),
                    'only scraper can collect'
                );
            } else {
                assert(destination_id != planet_id, 'cannot send to own planet');
                assert(
                    !self.is_noob_protected(planet_id, destination_id), 'noob protection active'
                );
            }

            self.check_enough_ships(planet_id, f);
            // Calculate distance
            let distance = fleet::get_distance(self.planet_position.read(planet_id), destination);

            // Calculate time
            let techs = self.get_tech_levels(planet_id);
            let speed = fleet::get_fleet_speed(f, techs);
            let travel_time = fleet::get_flight_time(speed, distance);

            // Check numeber of mission
            let active_missions = self.active_missions_len.read(planet_id);
            assert(active_missions < techs.digital.into() + 1, 'max active missions');

            // Pay for fuel
            let consumption = fleet::get_fuel_consumption(f, distance);
            let mut cost: ERC20s = Default::default();
            cost.tritium = consumption;
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);

            // Write mission
            let time_now = get_block_timestamp();
            let mut mission: Mission = Default::default();
            mission.time_start = time_now;
            mission.destination = self.get_position_slot_occupant(destination);
            mission.time_arrival = time_now + travel_time;
            mission.fleet = f;

            if is_debris_collection {
                mission.is_debris = true;
                self.add_active_mission(planet_id, mission);
                self
                    .emit(
                        Event::FleetSent(
                            FleetSent {
                                time: time_now,
                                origin: planet_id,
                                destination: destination_id,
                                mission_type: 'debris collection'
                            }
                        )
                    );
            } else {
                let id = self.add_active_mission(planet_id, mission);
                mission.is_debris = false;
                let mut hostile_mission: HostileMission = Default::default();
                hostile_mission.origin = planet_id;
                hostile_mission.id_at_origin = id;
                hostile_mission.time_arrival = mission.time_arrival;
                hostile_mission
                    .number_of_ships = fleet::calculate_number_of_ships(f, Zeroable::zero());

                self.add_hostile_mission(destination_id, hostile_mission);
                self
                    .emit(
                        Event::FleetSent(
                            FleetSent {
                                time: time_now,
                                origin: planet_id,
                                destination: destination_id,
                                mission_type: 'attack'
                            }
                        )
                    );
            }

            // Write new fleet levels
            self.fleet_leave_planet(planet_id, f);
            self.last_active.write(planet_id, get_block_timestamp());
        }

        fn attack_planet(ref self: ContractState, mission_id: usize) {
            let caller = get_caller_address();
            let origin = self.get_owned_planet(caller);
            let mut mission = self.active_missions.read((origin, mission_id));
            assert(!mission.is_zero(), 'the mission is empty');
            assert(mission.destination != origin, 'cannot attack own planet');
            let time_now = get_block_timestamp();
            assert(time_now >= mission.time_arrival, 'destination not reached yet');
            let defender_fleet = self.get_ships_levels(mission.destination);
            let defences = self.get_defences_levels(mission.destination);
            let t1 = self.get_tech_levels(origin);
            let t2 = self.get_tech_levels(mission.destination);
            let celestia_before = self.get_celestia_available(mission.destination);

            let time_since_arrived = time_now - mission.time_arrival;
            let mut attacker_fleet: Fleet = mission.fleet;

            if time_since_arrived > HOUR {
                let decay_amount = fleet::calculate_fleet_loss(time_since_arrived - HOUR);
                attacker_fleet = fleet::decay_fleet(mission.fleet, decay_amount);
            }

            let (f1, f2, d) = fleet::war(attacker_fleet, t1, defender_fleet, defences, t2);

            // calculate debris and update field
            let debris1 = fleet::get_debris(mission.fleet, f1, 0);
            let debris2 = fleet::get_debris(defender_fleet, f2, celestia_before - d.celestia);
            let total_debris = debris1 + debris2;
            let current_debries_field = self.planet_debris_field.read(mission.destination);
            self
                .planet_debris_field
                .write(mission.destination, current_debries_field + total_debris);

            self.update_fleet_levels_after_attack(mission.destination, f2);
            self.update_defences_after_attack(mission.destination, d);
            let mut loot_amount: ERC20s = Default::default();

            if f1.is_zero() {
                self.active_missions.write((origin, mission_id), Zeroable::zero());
            } else {
                let spendable = self.get_spendable_resources(mission.destination);
                let storage = fleet::get_fleet_cargo_capacity(f1);
                loot_amount = fleet::load_resources(spendable, storage);
                self.resources_timer.write(mission.destination, time_now);
                self
                    .pay_resources_erc20(
                        self.erc721.read().ownerOf(mission.destination.into()), loot_amount
                    );
                self.receive_resources_erc20(get_caller_address(), loot_amount);
                self.fleet_return_planet(origin, f1);
                self.active_missions.write((origin, mission_id), Zeroable::zero());
            }

            self.remove_hostile_mission(mission.destination, mission_id);

            let attacker_loss = self.calculate_fleet_loss(mission.fleet, f1);
            let defender_loss = self.calculate_fleet_loss(defender_fleet, f2);
            let defences_loss = self.calculate_defences_loss(defences, d);

            self.update_points_after_attack(origin, attacker_loss, Zeroable::zero());
            self.update_points_after_attack(mission.destination, defender_loss, defences_loss);

            self
                .emit_battle_report(
                    time_now,
                    origin,
                    self.planet_position.read(origin),
                    mission.fleet,
                    attacker_loss,
                    mission.destination,
                    self.planet_position.read(mission.destination),
                    defender_fleet,
                    defender_loss,
                    defences,
                    defences_loss,
                    loot_amount,
                    total_debris
                );
        }

        fn recall_fleet(ref self: ContractState, mission_id: usize) {
            let origin = self.get_owned_planet(get_caller_address());
            let mission = self.active_missions.read((origin, mission_id));
            assert(!mission.is_zero(), 'no fleet to recall');
            self.fleet_return_planet(origin, mission.fleet);
            self.active_missions.write((origin, mission_id), Zeroable::zero());
            self.remove_hostile_mission(mission.destination, mission_id);
        }

        fn collect_debris(ref self: ContractState, mission_id: usize) {
            let caller = get_caller_address();
            let origin = self.get_owned_planet(caller);

            let mut mission = self.active_missions.read((origin, mission_id));
            assert(!mission.is_zero(), 'the mission is empty');
            assert(mission.is_debris, 'not a debris mission');

            let time_now = get_block_timestamp();
            assert(time_now >= mission.time_arrival, 'destination not reached yet');

            let time_since_arrived = time_now - mission.time_arrival;
            let mut collector_fleet: Fleet = mission.fleet;

            if time_since_arrived > HOUR {
                let decay_amount = fleet::calculate_fleet_loss(time_since_arrived - HOUR);
                collector_fleet = fleet::decay_fleet(mission.fleet, decay_amount);
            }

            let debris = self.planet_debris_field.read(mission.destination);
            let storage = fleet::get_fleet_cargo_capacity(collector_fleet);
            let collectible_debris = fleet::get_collectible_debris(storage, debris);
            let new_debris = Debris {
                steel: debris.steel - collectible_debris.steel,
                quartz: debris.quartz - collectible_debris.quartz
            };

            self.planet_debris_field.write(mission.destination, new_debris);

            let erc20 = ERC20s {
                steel: collectible_debris.steel,
                quartz: collectible_debris.quartz,
                tritium: Zeroable::zero()
            };

            self.receive_resources_erc20(caller, erc20);
            self
                .scraper_available
                .write(origin, self.scraper_available.read(origin) + collector_fleet.scraper);
            self.active_missions.write((origin, mission_id), Zeroable::zero());
            let active_missions = self.active_missions_len.read(origin);
            self.active_missions_len.write(origin, active_missions - 1);
            self
                .emit(
                    Event::DebrisCollected(
                        DebrisCollected {
                            time: time_now,
                            debris_field_id: mission.destination,
                            amount: collectible_debris,
                        }
                    )
                );
        }

        /////////////////////////////////////////////////////////////////////
        //                         View Functions                                
        /////////////////////////////////////////////////////////////////////
        fn get_receiver(self: @ContractState) -> ContractAddress {
            self.receiver.read()
        }
        fn get_token_addresses(self: @ContractState) -> Tokens {
            self.get_tokens_addresses()
        }

        fn get_current_planet_price(self: @ContractState) -> u128 {
            let time_elapsed = (get_block_timestamp() - self.universe_start_time.read()) / DAY;
            self.get_planet_price(time_elapsed)
        }

        fn get_number_of_planets(self: @ContractState) -> u16 {
            self.number_of_planets.read()
        }

        fn get_generated_planets_positions(self: @ContractState) -> Array<PlanetPosition> {
            let mut arr: Array<PlanetPosition> = array![];
            let mut i = self.get_number_of_planets();
            loop {
                if i.is_zero() {
                    break;
                }
                let position = self.get_planet_position(i);
                arr.append(position);
                i -= 1;
            };
            arr
        }

        fn get_planet_position(self: @ContractState, planet_id: u16) -> PlanetPosition {
            self.planet_position.read(planet_id)
        }

        fn get_position_slot_occupant(self: @ContractState, position: PlanetPosition) -> u16 {
            self.position_to_planet.read(position)
        }

        fn get_debris_field(self: @ContractState, planet_id: u16) -> Debris {
            self.planet_debris_field.read(planet_id)
        }

        fn get_last_active(self: @ContractState, planet_id: u16) -> u64 {
            self.last_active.read(planet_id)
        }

        fn get_planet_points(self: @ContractState, planet_id: u16) -> u128 {
            self.resources_spent.read(planet_id) / 1000
        }

        fn get_spendable_resources(self: @ContractState, planet_id: u16) -> ERC20s {
            let planet_owner = self.erc721.read().ownerOf(planet_id.into());
            let steel = self.steel.read().balance_of(planet_owner).low / E18;
            let quartz = self.quartz.read().balance_of(planet_owner).low / E18;
            let tritium = self.tritium.read().balance_of(planet_owner).low / E18;
            ERC20s { steel: steel, quartz: quartz, tritium: tritium }
        }

        fn get_collectible_resources(self: @ContractState, planet_id: u16) -> ERC20s {
            let time_elapsed = self.time_since_last_collection(planet_id);
            let position = self.planet_position.read(planet_id);
            let temp = self.calculate_avg_temperature(position.orbit);
            let speed = self.uni_speed.read();
            let steel = Production::steel(self.steel_mine_level.read(planet_id))
                * speed
                * time_elapsed.into()
                / HOUR.into();
            let quartz = Production::quartz(self.quartz_mine_level.read(planet_id))
                * speed
                * time_elapsed.into()
                / HOUR.into();
            let tritium = Production::tritium(
                self.tritium_mine_level.read(planet_id), temp, self.uni_speed.read()
            )
                * time_elapsed.into()
                / HOUR.into();
            ERC20s { steel: steel, quartz: quartz, tritium: tritium }
        }

        fn get_energy_available(self: @ContractState, planet_id: u16) -> u128 {
            let compounds_levels = NoGame::get_compounds_levels(self, planet_id);
            let gross_production = Production::energy(compounds_levels.energy);
            let celestia_production = (self.celestia_available.read(planet_id).into() * 15);
            let energy_required = (self.calculate_energy_consumption(compounds_levels));
            if (gross_production + celestia_production < energy_required) {
                return 0;
            } else {
                return gross_production + celestia_production - energy_required;
            }
        }

        fn get_compounds_levels(self: @ContractState, planet_id: u16) -> CompoundsLevels {
            (CompoundsLevels {
                steel: self.steel_mine_level.read(planet_id),
                quartz: self.quartz_mine_level.read(planet_id),
                tritium: self.tritium_mine_level.read(planet_id),
                energy: self.energy_plant_level.read(planet_id),
                lab: self.lab_level.read(planet_id),
                dockyard: self.dockyard_level.read(planet_id)
            })
        }

        fn get_compounds_upgrade_cost(self: @ContractState, planet_id: u16) -> CompoundsCost {
            let steel = CompoundCost::steel(self.steel_mine_level.read(planet_id), 1);
            let quartz = CompoundCost::quartz(self.quartz_mine_level.read(planet_id), 1);
            let tritium = CompoundCost::tritium(self.tritium_mine_level.read(planet_id), 1);
            let energy = CompoundCost::energy(self.energy_plant_level.read(planet_id), 1);
            let lab = CompoundCost::lab(self.lab_level.read(planet_id), 1);
            let dockyard = CompoundCost::dockyard(self.dockyard_level.read(planet_id), 1);
            CompoundsCost {
                steel: steel,
                quartz: quartz,
                tritium: tritium,
                energy: energy,
                lab: lab,
                dockyard: dockyard
            }
        }

        fn get_energy_for_upgrade(self: @ContractState, planet_id: u16) -> EnergyCost {
            let steel = Consumption::base(self.steel_mine_level.read(planet_id) + 1)
                - Consumption::base(self.steel_mine_level.read(planet_id));
            let quartz = Consumption::base(self.quartz_mine_level.read(planet_id) + 1)
                - Consumption::base(self.quartz_mine_level.read(planet_id));
            let tritium = Consumption::tritium(self.tritium_mine_level.read(planet_id) + 1)
                - Consumption::tritium(self.tritium_mine_level.read(planet_id));

            EnergyCost { steel: steel, quartz: quartz, tritium: tritium }
        }

        fn get_energy_gain_after_upgrade(self: @ContractState, planet_id: u16) -> u128 {
            let compounds_levels = NoGame::get_compounds_levels(self, planet_id);
            Production::energy(compounds_levels.energy + 1)
                - Production::energy(compounds_levels.energy)
        }

        fn get_celestia_production(self: @ContractState, planet_id: u16) -> u16 {
            let position = self.get_planet_position(planet_id);
            self.position_to_celestia_production(position.orbit)
        }

        fn get_techs_levels(self: @ContractState, planet_id: u16) -> TechLevels {
            self.get_tech_levels(planet_id)
        }

        fn get_techs_upgrade_cost(self: @ContractState, planet_id: u16) -> TechsCost {
            let techs = self.get_tech_levels(planet_id);
            self.techs_cost(techs)
        }

        fn get_ships_levels(self: @ContractState, planet_id: u16) -> Fleet {
            Fleet {
                carrier: self.carrier_available.read(planet_id),
                scraper: self.scraper_available.read(planet_id),
                sparrow: self.sparrow_available.read(planet_id),
                frigate: self.frigate_available.read(planet_id),
                armade: self.armade_available.read(planet_id),
            }
        }

        fn get_celestia_available(self: @ContractState, planet_id: u16) -> u32 {
            self.celestia_available.read(planet_id)
        }

        fn get_ships_cost(self: @ContractState) -> ShipsCost {
            ShipsCost {
                carrier: ERC20s { steel: 2000, quartz: 2000, tritium: 0 },
                celestia: ERC20s { steel: 0, quartz: 2000, tritium: 500 },
                scraper: ERC20s { steel: 10000, quartz: 6000, tritium: 2000 },
                sparrow: ERC20s { steel: 3000, quartz: 1000, tritium: 0 },
                frigate: ERC20s { steel: 20000, quartz: 7000, tritium: 2000 },
                armade: ERC20s { steel: 45000, quartz: 15000, tritium: 0 }
            }
        }

        fn get_defences_levels(self: @ContractState, planet_id: u16) -> DefencesLevels {
            DefencesLevels {
                celestia: self.celestia_available.read(planet_id),
                blaster: self.blaster_available.read(planet_id),
                beam: self.beam_available.read(planet_id),
                astral: self.astral_available.read(planet_id),
                plasma: self.plasma_available.read(planet_id),
            }
        }

        fn get_defences_cost(self: @ContractState) -> DefencesCost {
            DefencesCost {
                blaster: ERC20s { steel: 2000, quartz: 0, tritium: 0 },
                beam: ERC20s { steel: 6000, quartz: 2000, tritium: 0 },
                astral: ERC20s { steel: 20000, quartz: 15000, tritium: 2000 },
                plasma: ERC20s { steel: 50000, quartz: 50000, tritium: 30000 },
            }
        }

        fn is_noob_protected(self: @ContractState, planet1_id: u16, planet2_id: u16) -> bool {
            let p1_points = self.get_planet_points(planet1_id);
            let p2_points = self.get_planet_points(planet2_id);
            if p1_points > p2_points {
                return p1_points > p2_points * 5;
            } else {
                return p2_points > p1_points * 5;
            }
        }

        fn get_mission_details(self: @ContractState, planet_id: u16, mission_id: usize) -> Mission {
            self.active_missions.read((planet_id, mission_id))
        }

        fn get_active_missions(self: @ContractState, planet_id: u16) -> Array<Mission> {
            let mut arr: Array<Mission> = array![];
            let len = self.active_missions_len.read(planet_id);
            let mut i = 1;
            loop {
                if i > len {
                    break;
                }
                let mission = self.active_missions.read((planet_id, i));
                if !mission.is_zero() {
                    arr.append(mission);
                }
                i += 1;
            };
            arr
        }

        fn get_hostile_missions(self: @ContractState, planet_id: u16) -> Array<HostileMission> {
            let mut arr: Array<HostileMission> = array![];
            let len = self.hostile_missions_len.read(planet_id);
            let mut i = 1;
            loop {
                if i > len {
                    break;
                }
                let mission = self.hostile_missions.read((planet_id, i));
                if !mission.is_zero() {
                    arr.append(mission);
                }
                i += 1;
            };
            arr
        }

        fn get_travel_time(
            self: @ContractState,
            origin: PlanetPosition,
            destination: PlanetPosition,
            fleet: Fleet,
            techs: TechLevels
        ) -> u64 {
            let destination_id = self.position_to_planet.read(destination);
            assert(!destination_id.is_zero(), 'no planet at destination');
            let distance = fleet::get_distance(origin, destination);
            let speed = fleet::get_fleet_speed(fleet, techs);
            fleet::get_flight_time(speed, distance)
        }

        fn get_fuel_consumption(
            self: @ContractState, origin: PlanetPosition, destination: PlanetPosition, fleet: Fleet
        ) -> u128 {
            let distance = fleet::get_distance(origin, destination);
            fleet::get_fuel_consumption(fleet, distance)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_planet_price(self: @ContractState, time_elapsed: u64) -> u128 {
            let auction = LinearVRGDA {
                target_price: FixedTrait::new(self.token_price.read(), false),
                decay_constant: FixedTrait::new(_0_05, true),
                per_time_unit: FixedTrait::new_unscaled(10, false),
            };
            let planet_sold: u128 = self.number_of_planets.read().into();
            auction
                .get_vrgda_price(
                    FixedTrait::new_unscaled(time_elapsed.into(), false),
                    FixedTrait::new_unscaled(planet_sold, false)
                )
                .mag
                * E18
                / ONE
        }

        // fn calculate_planet_position(self: @ContractState) -> PlanetPosition {
        //     let mut position: PlanetPosition = Default::default();
        //     let rand = self.rand.read();
        //     loop {
        //         position.system = (rand.next() % 200 + 1).try_into().unwrap();
        //         position.orbit = (rand.next() % 10 + 1).try_into().unwrap();
        //         let calculated_token_id = self.position_to_planet.read(position);
        //         if self.planet_position.read(calculated_token_id).is_zero() {
        //             break;
        //         }
        //         continue;
        //     };
        //     position
        // }

        #[inline(always)]
        fn get_position_from_raw(self: @ContractState, raw_position: u16) -> PlanetPosition {
            PlanetPosition {
                system: (raw_position / 10).try_into().unwrap(),
                orbit: (raw_position % 10).try_into().unwrap()
            }
        }


        #[inline(always)]
        fn get_owned_planet(self: @ContractState, caller: ContractAddress) -> u16 {
            let planet_id = self.erc721.read().token_of(caller);
            planet_id.low.try_into().unwrap()
        }

        /// Collects resources for a given contract and caller.
        ///
        /// This function is responsible for gathering resources based on the caller's ownership
        /// of a specific planet token. The production is calculated based on the token's associated planet,
        /// and resources are received using an ERC20 token standard.
        ///
        /// # Parameters
        ///
        /// - `ref self`: Reference to the current contract state.
        /// - `caller`: Address of the caller.
        ///
        /// # Behavior
        ///
        /// - Retrieves the caller's address using the `get_caller_address` function.
        /// - Gets the planet ID that is owned by the caller using `self.get_owned_planet`.
        /// - Calculates the production for the planet using `self.calculate_production`.
        /// - Receives the resources using `self.receive_resources_erc20`.
        /// - Writes the current block timestamp to the `resources_timer` for the planet.
        ///
        fn _collect_resources(ref self: ContractState, caller: ContractAddress) {
            let caller = get_caller_address();
            let planet_id = self.get_owned_planet(caller);
            assert(!planet_id.is_zero(), 'planet does not exist');
            let production = self.calculate_production(planet_id);
            self.receive_resources_erc20(caller, production);
            self.resources_timer.write(planet_id, get_block_timestamp());
        }

        /// Returns the available ERC20 tokens for a specific caller's address.
        ///
        /// This function retrieves the balances of three different tokens: steel, quartz, and tritium,
        /// for the given caller's address.
        ///
        /// # Parameters
        ///
        /// * `self`: The state of the contract, containing the addresses of the ERC20 tokens.
        /// * `caller`: The address of the contract making the call.
        ///
        /// # Returns
        ///
        /// An instance of `ERC20s` struct containing the available balances for steel, quartz, and tritium tokens.
        ///
        fn get_erc20s_available(self: @ContractState, caller: ContractAddress) -> ERC20s {
            let _steel = self.steel.read().balance_of(caller);
            let _quartz = self.quartz.read().balance_of(caller);
            let _tritium = self.tritium.read().balance_of(caller);
            ERC20s {
                steel: _steel.try_into().unwrap(),
                quartz: _quartz.try_into().unwrap(),
                tritium: _tritium.try_into().unwrap()
            }
        }

        /// Calculates the production of resources on a given planet based on the current
        /// state of the contract and the current time.
        ///
        /// # Parameters
        ///
        /// * `self`: A reference to the current state of the contract.
        /// * `planet_id`: The unique identifier for the planet for which to calculate the production.
        ///
        /// # Returns
        ///
        /// Returns a `Resources` structure containing the amounts of steel, quartz, tritium,
        /// and energy produced on the planet since the last collection time.
        ///
        /// # Notes
        ///
        /// This function takes into account various factors like the levels of mines,
        /// available energy, and the time elapsed since the last collection. The production
        /// is then scaled based on available and required energy, and the result is returned
        /// as a `Resources` structure.
        fn calculate_production(self: @ContractState, planet_id: u16) -> ERC20s {
            let time_now = get_block_timestamp();
            let last_collection_time = self.resources_timer.read(planet_id);
            let time_elapsed = time_now - last_collection_time;
            let mines_levels = NoGame::get_compounds_levels(self, planet_id);
            let position = self.planet_position.read(planet_id);
            let temp = self.calculate_avg_temperature(position.orbit);
            let speed = self.uni_speed.read();
            let steel_available = Production::steel(mines_levels.steel)
                * speed
                * time_elapsed.into()
                / HOUR.into();

            let quartz_available = Production::quartz(mines_levels.quartz)
                * speed
                * time_elapsed.into()
                / HOUR.into();

            let tritium_available = Production::tritium(mines_levels.tritium, temp, speed)
                * time_elapsed.into()
                / HOUR.into();
            let energy_available = Production::energy(mines_levels.energy);
            let energy_required = Consumption::base(mines_levels.steel)
                + Consumption::base(mines_levels.quartz)
                + Consumption::base(mines_levels.tritium);
            if energy_available < energy_required {
                let _steel = Compounds::production_scaler(
                    steel_available, energy_available, energy_required
                );
                let _quartz = Compounds::production_scaler(
                    quartz_available, energy_available, energy_required
                );
                let _tritium = Compounds::production_scaler(
                    tritium_available, energy_available, energy_required
                );

                return ERC20s { steel: _steel, quartz: _quartz, tritium: _tritium, };
            }

            ERC20s { steel: steel_available, quartz: quartz_available, tritium: tritium_available, }
        }

        fn calculate_energy_consumption(self: @ContractState, compounds: CompoundsLevels) -> u128 {
            Consumption::base(compounds.steel)
                + Consumption::base(compounds.quartz)
                + Consumption::base(compounds.tritium)
        }

        /// Receives resources in ERC20 token format and mints the corresponding amounts to a contract address.
        ///
        /// This function takes in a contract state, a contract address to send the tokens to, and the resources amounts for three different materials: steel, quartz, and tritium.
        /// It retrieves the token addresses for these materials from the contract state and then mints the corresponding amounts in ERC20 tokens.
        ///
        /// # Arguments
        ///
        /// * `self`: The current contract state, must implement the `ContractState` trait.
        /// * `to`: The `ContractAddress` where the ERC20 tokens will be minted.
        /// * `amounts`: A `Resources` struct containing the amounts of steel, quartz, and tritium to mint.
        ///
        fn receive_resources_erc20(self: @ContractState, to: ContractAddress, amounts: ERC20s) {
            self.steel.read().mint(to, (amounts.steel * E18).into());
            self.quartz.read().mint(to, (amounts.quartz * E18).into());
            self.tritium.read().mint(to, (amounts.tritium * E18).into());
        }

        /// Burns the specified amount of ERC20 tokens from the given account.
        ///
        /// This function takes the specified amounts of steel, quartz, and tritium tokens,
        /// multiplies each amount by 10^18 (represented by `E18`), and burns them from the
        /// account's balance.
        ///
        /// # Arguments
        ///
        /// * `self`: A reference to the contract state.
        /// * `account`: The address of the contract containing the ERC20 tokens to be burned.
        /// * `amounts`: An `ERC20s` struct containing the amounts of steel, quartz, and tritium tokens to be burned.
        ///
        /// # Note
        ///
        /// This function internally calls `self.get_tokens_addresses` to obtain the
        /// addresses for the cNGorresponding tokens and leverages the `IERC20Dispatcher` for
        /// the burn operation.
        ///
        fn pay_resources_erc20(self: @ContractState, account: ContractAddress, amounts: ERC20s) {
            self.steel.read().burn(account, (amounts.steel * E18).into());
            self.quartz.read().burn(account, (amounts.quartz * E18).into());
            self.tritium.read().burn(account, (amounts.tritium * E18).into());
        }

        fn receive_loot_erc20(
            self: @ContractState, from: ContractAddress, to: ContractAddress, amounts: ERC20s
        ) {
            self.steel.read().transfer_from(from, to, (amounts.steel * E18).into());
            self.quartz.read().transfer_from(from, to, (amounts.quartz * E18).into());
            self.tritium.read().transfer_from(from, to, (amounts.tritium * E18).into());
        }

        /// Checks if the caller has enough resources based on the provided amounts of ERC20 tokens.
        ///
        /// This function compares the required amounts of steel, quartz, and tritium with the available
        /// amounts for the given caller. The available amounts are scaled down by a factor of E18 (10^18) before
        /// comparison.
        ///
        /// # Arguments
        ///
        /// * `self` - A reference to the contract's current state.
        /// * `caller` - The address of the calling contract.
        /// * `amounts` - A struct containing the amounts of steel, quartz, and tritium that are required.
        ///
        /// # Panics
        ///
        /// The function will panic if:
        /// * The amount of steel required is greater than the available steel scaled down by E18.
        /// * The amount of quartz required is greater than the available quartz scaled down by E18.
        /// * The amount of tritium required is greater than the available tritium scaled down by E18.
        ///
        fn check_enough_resources(self: @ContractState, caller: ContractAddress, amounts: ERC20s) {
            let available: ERC20s = self.get_erc20s_available(caller);
            assert(amounts.steel <= available.steel / E18, 'Not enough steel');
            assert(amounts.quartz <= available.quartz / E18, 'Not enough quartz');
            assert(amounts.tritium <= available.tritium / E18, 'Not enough tritium');
        }

        /// Returns the addresses for various tokens stored within the contract's state.
        ///
        /// This function reads the current addresses for the steel, quartz, and tritium tokens
        /// from the contract's state and returns them encapsulated in a `Tokens` struct.
        ///
        /// # Returns
        /// A `Tokens` struct containing the addresses for the following tokens:
        /// - `steel`: The address of the steel token.
        /// - `quartz`: The address of the quartz token.
        /// - `tritium`: The address of the tritium token.
        ///
        fn get_tokens_addresses(self: @ContractState) -> Tokens {
            Tokens {
                erc721: self.erc721.read().contract_address,
                steel: self.steel.read().contract_address,
                quartz: self.quartz.read().contract_address,
                tritium: self.tritium.read().contract_address
            }
        }

        /// Updates the resource points for a specified planet within a contract state.
        ///
        /// This function adds the total of `spent.steel` and `spent.quartz` to the current resources
        /// spent for the specified `planet_id` in the contract state's resources.
        ///
        /// # Arguments
        ///
        /// * `self`: A mutable reference to the current contract state.
        /// * `planet_id`: The unique identifier of the planet for which the resources are being updated.
        /// * `spent`: A value of type `ERC20s` representing the resources spent, including steel and quartz.
        ///
        fn update_planet_points(ref self: ContractState, planet_id: u16, spent: ERC20s) {
            self
                .resources_spent
                .write(
                    planet_id, self.resources_spent.read(planet_id) + spent.steel + spent.quartz
                );
        }

        /// Returns the time elapsed since the last collection for a specified planet.
        ///
        /// This function calculates the time that has passed since the last resource collection
        /// on a given planet, identified by its `planet_id`.
        ///
        /// # Arguments
        ///
        /// * `self`: A reference to the contract's state.
        /// * `planet_id`: The unique identifier for the planet.
        ///
        /// # Returns
        ///
        /// Returns a 64-bit unsigned integer representing the time in seconds 
        ///
        fn time_since_last_collection(self: @ContractState, planet_id: u16) -> u64 {
            get_block_timestamp() - self.resources_timer.read(planet_id)
        }

        fn get_tech_levels(self: @ContractState, planet_id: u16) -> TechLevels {
            TechLevels {
                energy: self.energy_innovation_level.read(planet_id),
                digital: self.digital_systems_level.read(planet_id),
                beam: self.beam_technology_level.read(planet_id),
                armour: self.armour_innovation_level.read(planet_id),
                ion: self.ion_systems_level.read(planet_id),
                plasma: self.plasma_engineering_level.read(planet_id),
                weapons: self.weapons_development_level.read(planet_id),
                shield: self.shield_tech_level.read(planet_id),
                spacetime: self.spacetime_warp_level.read(planet_id),
                combustion: self.combustive_engine_level.read(planet_id),
                thrust: self.thrust_propulsion_level.read(planet_id),
                warp: self.warp_drive_level.read(planet_id)
            }
        }

        fn techs_cost(self: @ContractState, techs: TechLevels) -> TechsCost {
            let costs: TechsCost = Lab::base_tech_costs();
            let energy = Lab::get_tech_cost(techs.energy, techs.energy + 1, costs.energy);
            let digital = Lab::get_tech_cost(techs.digital, techs.digital + 1, costs.digital);
            let beam = Lab::get_tech_cost(techs.beam, techs.beam + 1, costs.beam);
            let ion = Lab::get_tech_cost(techs.ion, techs.ion + 1, costs.ion);
            let plasma = Lab::get_tech_cost(techs.plasma, techs.plasma + 1, costs.plasma);
            let spacetime = Lab::get_tech_cost(
                techs.spacetime, techs.spacetime + 1, costs.spacetime
            );
            let combustion = Lab::get_tech_cost(
                techs.combustion, techs.combustion + 1, costs.combustion
            );
            let thrust = Lab::get_tech_cost(techs.thrust, techs.thrust + 1, costs.thrust);
            let warp = Lab::get_tech_cost(techs.warp, techs.warp + 1, costs.warp);
            let armour = Lab::get_tech_cost(techs.armour, techs.armour + 1, costs.armour);
            let weapons = Lab::get_tech_cost(techs.weapons, techs.weapons + 1, costs.weapons);
            let shield = Lab::get_tech_cost(techs.shield, techs.shield + 1, costs.shield);

            TechsCost {
                energy: energy,
                digital: digital,
                beam: beam,
                ion: ion,
                plasma: plasma,
                spacetime: spacetime,
                combustion: combustion,
                thrust: thrust,
                warp: warp,
                armour: armour,
                weapons: weapons,
                shield: shield
            }
        }

        fn fleet_leave_planet(ref self: ContractState, planet_id: u16, fleet: Fleet) {
            if fleet.carrier > 0 {
                self
                    .carrier_available
                    .write(planet_id, self.carrier_available.read(planet_id) - fleet.carrier);
            }
            if fleet.scraper > 0 {
                self
                    .scraper_available
                    .write(planet_id, self.scraper_available.read(planet_id) - fleet.scraper);
            }
            if fleet.sparrow > 0 {
                self
                    .sparrow_available
                    .write(planet_id, self.sparrow_available.read(planet_id) - fleet.sparrow);
            }
            if fleet.frigate > 0 {
                self
                    .frigate_available
                    .write(planet_id, self.frigate_available.read(planet_id) - fleet.frigate);
            }
            if fleet.armade > 0 {
                self
                    .armade_available
                    .write(planet_id, self.armade_available.read(planet_id) - fleet.armade);
            }
        }

        fn fleet_return_planet(ref self: ContractState, planet_id: u16, fleet: Fleet) {
            if fleet.carrier > 0 {
                self
                    .carrier_available
                    .write(planet_id, self.carrier_available.read(planet_id) + fleet.carrier);
            }
            if fleet.scraper > 0 {
                self
                    .scraper_available
                    .write(planet_id, self.scraper_available.read(planet_id) + fleet.scraper);
            }
            if fleet.sparrow > 0 {
                self
                    .sparrow_available
                    .write(planet_id, self.sparrow_available.read(planet_id) + fleet.sparrow);
            }
            if fleet.frigate > 0 {
                self
                    .frigate_available
                    .write(planet_id, self.frigate_available.read(planet_id) + fleet.frigate);
            }
            if fleet.armade > 0 {
                self
                    .armade_available
                    .write(planet_id, self.armade_available.read(planet_id) + fleet.armade);
            }
        }

        fn check_enough_ships(self: @ContractState, planet_id: u16, fleet: Fleet) {
            assert(self.carrier_available.read(planet_id) >= fleet.carrier, 'not enough carrier-');
            assert(self.scraper_available.read(planet_id) >= fleet.scraper, 'not enough scrapers');
            assert(self.sparrow_available.read(planet_id) >= fleet.sparrow, 'not enough sparrows');
            assert(self.frigate_available.read(planet_id) >= fleet.frigate, 'not enough frigates');
            assert(self.armade_available.read(planet_id) >= fleet.armade, 'not enough armades');
        }

        fn update_fleet_levels_after_attack(ref self: ContractState, planet_id: u16, f: Fleet) {
            self.carrier_available.write(planet_id, f.carrier);
            self.scraper_available.write(planet_id, f.scraper);
            self.sparrow_available.write(planet_id, f.sparrow);
            self.frigate_available.write(planet_id, f.frigate);
            self.armade_available.write(planet_id, f.armade);
        }

        fn update_defences_after_attack(
            ref self: ContractState, planet_id: u16, d: DefencesLevels
        ) {
            self.celestia_available.write(planet_id, d.celestia);
            self.blaster_available.write(planet_id, d.blaster);
            self.beam_available.write(planet_id, d.beam);
            self.astral_available.write(planet_id, d.astral);
            self.plasma_available.write(planet_id, d.plasma);
        }

        fn add_active_mission(
            ref self: ContractState, planet_id: u16, mut mission: Mission
        ) -> usize {
            let len = self.active_missions_len.read(planet_id);
            let mut i = 1;
            loop {
                if i > len {
                    mission.id = i.try_into().expect('add active mission fail');
                    self.active_missions.write((planet_id, i), mission);
                    self.active_missions_len.write(planet_id, i);
                    break;
                }
                let read_mission = self.active_missions.read((planet_id, i));
                if read_mission.is_zero() {
                    mission.id = i.try_into().expect('add active mission fail');
                    self.active_missions.write((planet_id, i), mission);
                    break;
                }
                i += 1;
            };
            i
        }

        fn add_hostile_mission(ref self: ContractState, planet_id: u16, mission: HostileMission) {
            let len = self.hostile_missions_len.read(planet_id);
            let mut i = 1;
            loop {
                if i > len {
                    self.hostile_missions.write((planet_id, i), mission);
                    self.hostile_missions_len.write(planet_id, i);
                    break;
                }
                let read_mission = self.hostile_missions.read((planet_id, i));
                if read_mission.is_zero() {
                    self.hostile_missions.write((planet_id, i), mission);
                    break;
                }
                i += 1;
            };
        }

        fn remove_hostile_mission(ref self: ContractState, planet_id: u16, id_to_remove: usize) {
            let len = self.hostile_missions_len.read(planet_id);
            let mut i = 1;
            loop {
                if i > len {
                    break;
                }
                let mission = self.hostile_missions.read((planet_id, i));
                if mission.id_at_origin == id_to_remove {
                    self.hostile_missions.write((planet_id, i), Zeroable::zero());
                    break;
                }
                i += 1;
            }
        }

        fn position_to_celestia_production(self: @ContractState, orbit: u8) -> u16 {
            if orbit == 1 {
                return 48;
            }
            if orbit == 2 {
                return 41;
            }
            if orbit == 3 {
                return 36;
            }
            if orbit == 4 {
                return 32;
            }
            if orbit == 5 {
                return 27;
            }
            if orbit == 6 {
                return 24;
            }
            if orbit == 7 {
                return 21;
            }
            if orbit == 8 {
                return 17;
            }
            if orbit == 9 {
                return 14;
            } else {
                return 11;
            }
        }

        fn calculate_avg_temperature(self: @ContractState, orbit: u8) -> u16 {
            if orbit == 1 {
                return 230;
            }
            if orbit == 2 {
                return 170;
            }
            if orbit == 3 {
                return 120;
            }
            if orbit == 4 {
                return 70;
            }
            if orbit == 5 {
                return 60;
            }
            if orbit == 6 {
                return 50;
            }
            if orbit == 7 {
                return 40;
            }
            if orbit == 8 {
                return 40;
            }
            if orbit == 9 {
                return 20;
            } else {
                return 10;
            }
        }

        fn calculate_fleet_loss(self: @ContractState, a: Fleet, b: Fleet) -> Fleet {
            Fleet {
                carrier: a.carrier - b.carrier,
                scraper: a.scraper - b.scraper,
                sparrow: a.sparrow - b.sparrow,
                frigate: a.frigate - b.frigate,
                armade: a.armade - b.armade,
            }
        }

        fn calculate_defences_loss(
            self: @ContractState, a: DefencesLevels, b: DefencesLevels
        ) -> DefencesLevels {
            DefencesLevels {
                celestia: a.celestia - b.celestia,
                blaster: a.blaster - b.blaster,
                beam: a.beam - b.beam,
                astral: a.astral - b.astral,
                plasma: a.plasma - b.plasma,
            }
        }

        fn emit_battle_report(
            ref self: ContractState,
            time: u64,
            attacker: u16,
            attacker_position: PlanetPosition,
            attacker_initial_fleet: Fleet,
            attacker_fleet_loss: Fleet,
            defender: u16,
            defender_position: PlanetPosition,
            defender_initial_fleet: Fleet,
            defender_fleet_loss: Fleet,
            initial_defences: DefencesLevels,
            defences_loss: DefencesLevels,
            loot: ERC20s,
            debris: Debris
        ) {
            self
                .emit(
                    Event::BattleReport(
                        BattleReport {
                            time,
                            attacker,
                            attacker_position,
                            attacker_initial_fleet,
                            attacker_fleet_loss,
                            defender,
                            defender_position,
                            defender_initial_fleet,
                            defender_fleet_loss,
                            initial_defences,
                            defences_loss,
                            loot,
                            debris
                        }
                    )
                )
        }

        fn update_points_after_attack(
            ref self: ContractState, planet_id: u16, fleet: Fleet, defences: DefencesLevels
        ) {
            if fleet.is_zero() && defences.is_zero() {
                return;
            }
            let ships_cost = self.get_ships_cost();
            let ships_points = fleet.carrier.into()
                * (ships_cost.carrier.steel + ships_cost.carrier.quartz)
                + fleet.scraper.into() * (ships_cost.scraper.steel + ships_cost.scraper.quartz)
                + fleet.sparrow.into() * (ships_cost.sparrow.steel + ships_cost.sparrow.quartz)
                + fleet.frigate.into() * (ships_cost.frigate.steel + ships_cost.frigate.quartz)
                + fleet.armade.into() * (ships_cost.armade.steel + ships_cost.armade.quartz);

            let defences_cost = self.get_defences_cost();
            let defences_points = defences.celestia.into() * 2000
                + defences.blaster.into()
                    * (defences_cost.blaster.steel + defences_cost.blaster.quartz)
                + defences.beam.into() * (defences_cost.beam.steel + defences_cost.beam.quartz)
                + defences.astral.into()
                    * (defences_cost.astral.steel + defences_cost.astral.quartz)
                + defences.plasma.into()
                    * (defences_cost.plasma.steel + defences_cost.plasma.quartz);

            self
                .resources_spent
                .write(
                    planet_id,
                    self.resources_spent.read(planet_id) - (ships_points + defences_points)
                );
        }
    }
}

