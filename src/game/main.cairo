// TODOS: 
#[starknet::contract]
mod NoGame {
    use nogame::colony::colony::IColonyView;
    use nogame::colony::colony::IColonyWrite;
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
        SyscallResultTrait, class_hash::ClassHash
    };
    use core::poseidon::poseidon_hash_span;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    // Components
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use nogame::colony::colony::ColonyComponent;

    use nogame_fixed::f128::types::{Fixed, FixedTrait, ONE_u128 as ONE};
    use nogame::game::interface::INoGame;
    use nogame::libraries::types::{
        ETH_ADDRESS, BANK_ADDRESS, E18, DefencesCost, DefencesLevels, EnergyCost, ERC20s, erc20_mul,
        CompoundsCost, CompoundsLevels, ShipsLevels, ShipsCost, TechLevels, TechsCost, Tokens,
        PlanetPosition, Debris, Mission, IncomingMission, Fleet, MAX_NUMBER_OF_PLANETS, _0_05,
        PRICE, DAY, HOUR, Names, UpgradeType, BuildType, WEEK, SimulationResult, ColonyUpgradeType,
        ColonyBuildType, MissionCategory
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

    use snforge_std::PrintTrait;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    impl UpgradableInteralImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(
        path: ReentrancyGuardComponent, storage: reentrancyguard, event: ReentrancyGuardEvent
    );
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    component!(path: ColonyComponent, storage: colony, event: ColonyEvent);
    #[abi(embed_v0)]
    impl ColonyViewImpl = ColonyComponent::ColonyView<ContractState>;
    impl ColonyWriteImpl = ColonyComponent::ColonyWrite<ContractState>;
    impl ColonyInternalImpl = ColonyComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        initialized: bool,
        is_testnet: bool,
        receiver: ContractAddress,
        token_price: u128,
        uni_speed: u128,
        // General.
        number_of_planets: u32,
        planet_position: LegacyMap::<u32, PlanetPosition>,
        position_to_planet: LegacyMap::<PlanetPosition, u32>,
        planet_debris_field: LegacyMap::<u32, Debris>,
        universe_start_time: u64,
        resources_spent: LegacyMap::<u32, u128>,
        // mapping colony_planet_id to mother planet id
        colony_owner: LegacyMap::<u32, u32>,
        // Tokens.
        erc721: IERC721NoGameDispatcher,
        steel: IERC20NoGameDispatcher,
        quartz: IERC20NoGameDispatcher,
        tritium: IERC20NoGameDispatcher,
        ETH: IERC20CamelDispatcher,
        pioneer_nft_key: LegacyMap<ContractAddress, felt252>,
        resources_timer: LegacyMap::<u32, u64>,
        last_active: LegacyMap::<u32, u64>,
        compounds_level: LegacyMap::<(u32, felt252), u8>,
        techs_level: LegacyMap::<(u32, felt252), u8>,
        ships_level: LegacyMap::<(u32, felt252), u32>,
        defences_level: LegacyMap::<(u32, felt252), u32>,
        active_missions: LegacyMap::<(u32, u32), Mission>,
        active_missions_len: LegacyMap<u32, usize>,
        hostile_missions: LegacyMap<(u32, u32), IncomingMission>,
        hostile_missions_len: LegacyMap<u32, usize>,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancyguard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        colony: ColonyComponent::Storage
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
        FleetReturn: FleetReturn,
        BattleReport: BattleReport,
        DebrisCollected: DebrisCollected,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        ColonyEvent: ColonyComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct PlanetGenerated {
        id: u32,
        position: PlanetPosition,
        account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CompoundSpent {
        planet_id: u32,
        quantity: u8,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct TechSpent {
        planet_id: u32,
        quantity: u8,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct FleetSpent {
        planet_id: u32,
        quantity: u32,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct DefenceSpent {
        planet_id: u32,
        quantity: u32,
        spent: ERC20s
    }

    #[derive(Drop, starknet::Event)]
    struct FleetSent {
        origin: u32,
        destination: u32,
        mission_type: u8,
        fleet: Fleet,
    }

    #[derive(Drop, starknet::Event)]
    struct FleetReturn {
        docked_at: u32,
        mission_type: u8,
        fleet: Fleet,
    }

    #[derive(Drop, starknet::Event)]
    struct BattleReport {
        time: u64,
        attacker: u32,
        attacker_position: PlanetPosition,
        attacker_initial_fleet: Fleet,
        attacker_fleet_loss: Fleet,
        defender: u32,
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
        planet_id: u32,
        debris_field_id: u32,
        amount: Debris,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.universe_start_time.write(get_block_timestamp());
    }

    #[abi(embed_v0)]
    impl NoGame of INoGame<ContractState> {
        fn initializer(
            ref self: ContractState,
            erc721: ContractAddress,
            steel: ContractAddress,
            quartz: ContractAddress,
            tritium: ContractAddress,
            eth: ContractAddress,
            owner: ContractAddress,
            uni_speed: u128,
            token_price: u128,
            is_testnet: bool,
        ) {
            self.ownable.initializer(owner);
            self
                .init(
                    erc721, steel, quartz, tritium, eth, owner, uni_speed, token_price, is_testnet
                )
        }

        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(impl_hash);
        }

        /////////////////////////////////////////////////////////////////////
        //                         Planet Functions                                
        /////////////////////////////////////////////////////////////////////
        fn generate_mint_key(ref self: ContractState, secret: felt252) {
            let caller = get_caller_address();
            let planet_id = self.get_owned_planet(caller);
            assert(self.get_planet_points(planet_id) > 300, 'insufficient points');
            let params: Span<felt252> = array![planet_id.into(), caller.into(), secret].span();
            let hash = poseidon_hash_span(params);
            self.pioneer_nft_key.write(caller, hash);
        }

        fn get_mint_key(self: @ContractState, account: ContractAddress) -> felt252 {
            self.pioneer_nft_key.read(account)
        }

        fn generate_planet(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.erc721.read().balance_of(caller).is_zero(), 'caller already planet owner');
            let time_elapsed = (get_block_timestamp() - self.universe_start_time.read()) / DAY;
            let price: u256 = self.get_planet_price(time_elapsed).into();
            self.ETH.read().transferFrom(caller, self.ownable.owner(), price);
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

        fn generate_colony(ref self: ContractState) {
            let caller = get_caller_address();
            let planet_id = self.get_owned_planet(caller);
            let exo_tech = self.techs_level.read((planet_id, Names::EXOCRAFT));
            let max_colonies = if exo_tech % 2 == 1 {
                exo_tech / 2 + 1
            } else {
                exo_tech / 2
            };
            let current_colonies = self.colony.get_planet_colony_count(planet_id);
            assert!(
                current_colonies < max_colonies,
                "NoGame: max colonies {} reached, upgrade Exocraft tech to increase max colonies",
                max_colonies
            );
            let price: u256 = 0;
            if !price.is_zero() {
                self.ETH.read().transferFrom(caller, self.ownable.owner(), price);
            }

            let (colony_id, colony_position) = self.colony.generate_colony(planet_id);
            let id = ((planet_id * 1000) + colony_id.into());
            self.planet_position.write(id, colony_position);
            self.position_to_planet.write(colony_position, id);
            self.number_of_planets.write(self.number_of_planets.read() + 1);
            self.colony_owner.write(id, planet_id);
            self
                .emit(
                    Event::PlanetGenerated(
                        PlanetGenerated { id, position: colony_position, account: caller }
                    )
                );
        }

        fn collect_resources(ref self: ContractState) {
            let caller = get_caller_address();
            let planet_id = self.get_owned_planet(caller);
            let colonies = self.get_planet_colonies(planet_id);
            let speed = self.uni_speed.read();
            let mut i = 1;
            let colonies_len = colonies.len();
            let mut total_production: ERC20s = Default::default();
            loop {
                if colonies_len.is_zero() || i > colonies_len {
                    break;
                }
                let production = self
                    .colony
                    .collect_resources(speed, planet_id, i.try_into().unwrap());
                total_production = total_production + production;
                i += 1;
            };
            self.receive_resources_erc20(caller, total_production);
            self._collect_resources(get_caller_address());
        }

        fn collect_colony_resources(ref self: ContractState, colony_id: u8) {
            let caller = get_caller_address();
            let planet_id = self.get_owned_planet(caller);
            assert(!planet_id.is_zero(), 'planet does not exist');
            let speed = self.uni_speed.read();
            let production = self.colony.collect_resources(speed, planet_id, colony_id);
            self.receive_resources_erc20(caller, production);
        }

        /////////////////////////////////////////////////////////////////////
        //                         Mines Functions                                
        /////////////////////////////////////////////////////////////////////
        fn process_compound_upgrade(ref self: ContractState, component: UpgradeType, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let cost = self.upgrade_component(caller, planet_id, component, quantity);
            self.update_planet_points(planet_id, cost);
            self.emit(CompoundSpent { planet_id: planet_id, quantity, spent: cost })
        }

        fn process_tech_upgrade(ref self: ContractState, component: UpgradeType, quantity: u8) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let cost = self.upgrade_component(caller, planet_id, component, quantity);
            self.update_planet_points(planet_id, cost);
            self.emit(TechSpent { planet_id, quantity, spent: cost })
        }

        fn process_ship_build(ref self: ContractState, component: BuildType, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.compounds_level.read((planet_id, Names::DOCKYARD));
            let techs = self.get_tech_levels(planet_id);
            let cost = self
                .build_component(caller, planet_id, dockyard_level, techs, component, quantity);
            self.update_planet_points(planet_id, cost);
            self.emit(FleetSpent { planet_id, quantity, spent: cost })
        }

        fn process_defence_build(ref self: ContractState, component: BuildType, quantity: u32) {
            let caller = get_caller_address();
            self._collect_resources(caller);
            let planet_id = self.get_owned_planet(caller);
            let dockyard_level = self.compounds_level.read((planet_id, Names::DOCKYARD));
            let techs = self.get_tech_levels(planet_id);
            let cost = self
                .build_component(caller, planet_id, dockyard_level, techs, component, quantity);
            self.update_planet_points(planet_id, cost);
            self.emit(DefenceSpent { planet_id, quantity, spent: cost })
        }

        /////////////////////////////////////////////////////////////////////
        //                         Colony Functions                                
        /////////////////////////////////////////////////////////////////////
        fn process_colony_compound_upgrade(
            ref self: ContractState, colony_id: u8, name: ColonyUpgradeType, quantity: u8
        ) {
            let caller = get_caller_address();
            self.collect_colony_resources(colony_id);
            let planet_id = self.get_owned_planet(caller);
            let cost = self.upgrade_colony_component(caller, planet_id, colony_id, name, quantity);
            self.update_planet_points(planet_id, cost);
            self.emit(CompoundSpent { planet_id, quantity, spent: cost })
        }

        fn process_colony_unit_build(
            ref self: ContractState, colony_id: u8, name: ColonyBuildType, quantity: u32,
        ) {
            let caller = get_caller_address();
            self.collect_colony_resources(colony_id);
            let planet_id = self.get_owned_planet(caller);
            let cost = self.build_colony_component(caller, planet_id, colony_id, name, quantity);
            if name == ColonyBuildType::Carrier
                || name == ColonyBuildType::Scraper
                || name == ColonyBuildType::Sparrow
                || name == ColonyBuildType::Frigate
                || name == ColonyBuildType::Armade {
                self.emit(FleetSpent { planet_id, quantity, spent: cost })
            }
            self.update_planet_points(planet_id, cost);
        }

        /////////////////////////////////////////////////////////////////////
        //                         Fleet Functions                                
        /////////////////////////////////////////////////////////////////////
        fn send_fleet(
            ref self: ContractState,
            f: Fleet,
            destination: PlanetPosition,
            mission_type: u8,
            speed_modifier: u32,
            colony_id: u8,
        ) {
            let destination_id = self.position_to_planet.read(destination);
            assert(!destination_id.is_zero(), 'no planet at destination');
            let caller = get_caller_address();
            let planet_id = self.get_owned_planet(caller);
            let origin_id = if colony_id.is_zero() {
                planet_id
            } else {
                (planet_id * 1000) + colony_id.into()
            };

            if destination_id > 500 && mission_type == MissionCategory::TRANSPORT {
                assert(
                    self.get_colony_mother_planet(destination_id) == planet_id, 'not your colony'
                );
            }
            if mission_type == MissionCategory::ATTACK {
                if destination_id > 500 {
                    assert(
                        self.get_colony_mother_planet(destination_id) != planet_id,
                        'cannot attack own planet'
                    );
                } else {
                    assert(destination_id != planet_id, 'cannot attack own planet');
                }
            }
            let time_now = get_block_timestamp();

            self.check_enough_ships(planet_id, colony_id, f);
            // Calculate distance
            let distance = fleet::get_distance(self.planet_position.read(origin_id), destination);

            // Calculate time
            let techs = self.get_tech_levels(planet_id);
            let speed = fleet::get_fleet_speed(f, techs);
            let travel_time = fleet::get_flight_time(speed, distance, speed_modifier);

            // Check numeber of mission
            let active_missions = self.get_active_missions(planet_id).len();
            assert(active_missions < techs.digital.into() + 1, 'max active missions');

            // Pay for fuel
            let consumption = fleet::get_fuel_consumption(f, distance)
                * 100
                / speed_modifier.into();
            let mut cost: ERC20s = Default::default();
            cost.tritium = consumption;
            self.check_enough_resources(caller, cost);
            self.pay_resources_erc20(caller, cost);

            // Write mission
            let mut mission: Mission = Default::default();
            mission.time_start = time_now;
            mission.origin = origin_id;
            mission.destination = self.get_position_slot_occupant(destination);
            mission.time_arrival = time_now + travel_time;
            mission.fleet = f;

            if mission_type == MissionCategory::DEBRIS {
                assert(
                    !self.planet_debris_field.read(destination_id).is_zero(), 'empty debris fiels'
                );
                assert(f.scraper >= 1, 'no scrapers for collection');
                mission.category = MissionCategory::DEBRIS;
                self.add_active_mission(planet_id, mission);
                self
                    .emit(
                        Event::FleetSent(
                            FleetSent {
                                origin: planet_id,
                                destination: destination_id,
                                mission_type: MissionCategory::DEBRIS,
                                fleet: f,
                            }
                        )
                    );
            } else if mission_type == MissionCategory::TRANSPORT {
                mission.category = MissionCategory::TRANSPORT;
                self.add_active_mission(planet_id, mission);
                self
                    .emit(
                        Event::FleetSent(
                            FleetSent {
                                origin: planet_id,
                                destination: destination_id,
                                mission_type: MissionCategory::TRANSPORT,
                                fleet: f,
                            }
                        )
                    );
            } else {
                let is_inactive = time_now - self.last_active.read(destination_id) > WEEK;
                if !is_inactive {
                    assert(
                        !self.is_noob_protected(planet_id, destination_id), 'noob protection active'
                    );
                }
                mission.category = MissionCategory::ATTACK;
                let id = self.add_active_mission(planet_id, mission);
                let mut hostile_mission: IncomingMission = Default::default();
                hostile_mission.origin = planet_id;
                hostile_mission.id_at_origin = id;
                hostile_mission.time_arrival = mission.time_arrival;
                hostile_mission
                    .number_of_ships = fleet::calculate_number_of_ships(f, Zeroable::zero());
                hostile_mission.destination = destination_id;
                let is_colony = mission.destination > 1000;
                let target_planet = if is_colony {
                    self.colony_owner.read(mission.destination)
                } else {
                    mission.destination
                };
                self.add_incoming_mission(target_planet, hostile_mission);
                self
                    .emit(
                        Event::FleetSent(
                            FleetSent {
                                origin: planet_id,
                                destination: destination_id,
                                mission_type: MissionCategory::ATTACK,
                                fleet: f,
                            }
                        )
                    );
            }
            self.last_active.write(planet_id, time_now);
            // Write new fleet levels
            self.fleet_leave_planet(origin_id, f);
        }


        fn attack_planet(ref self: ContractState, mission_id: usize) {
            let caller = get_caller_address();
            let origin = self.get_owned_planet(caller);
            let mut mission = self.active_missions.read((origin, mission_id));
            assert(!mission.is_zero(), 'the mission is empty');
            assert(mission.category == MissionCategory::ATTACK, 'not an attack mission');
            assert(mission.destination != origin, 'cannot attack own planet');
            let time_now = get_block_timestamp();
            assert(time_now >= mission.time_arrival, 'destination not reached yet');
            let is_colony = mission.destination > 1000;
            let colony_mother_planet = if is_colony {
                self.colony_owner.read(mission.destination)
            } else {
                0
            };
            let colony_id = if is_colony {
                (mission.destination - colony_mother_planet * 1000).try_into().unwrap()
            } else {
                0
            };

            let mut t1 = self.get_tech_levels(origin);
            let (defender_fleet, defences, t2, celestia_before) = self
                .get_fleet_and_defences_before_battle(mission.destination);

            let time_since_arrived = time_now - mission.time_arrival;
            let mut attacker_fleet: Fleet = mission.fleet;

            if time_since_arrived > (2 * HOUR) {
                let decay_amount = fleet::calculate_fleet_loss(time_since_arrived - (2 * HOUR));
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

            if is_colony {
                self.colony.update_defences_after_attack(colony_mother_planet, colony_id, d);
            } else {
                self.update_defender_fleet_levels_after_attack(mission.destination, f2);
                self.update_defences_after_attack(mission.destination, d);
            }

            let (loot_spendable, loot_collectible) = self
                .calculate_loot_amount(mission.destination, f1);
            let total_loot = loot_spendable + loot_collectible;

            if !is_colony {
                self.process_loot_payment(mission.destination, loot_spendable);
            }
            self.receive_resources_erc20(get_caller_address(), total_loot);

            if is_colony {
                self.colony.reset_resource_timer(colony_mother_planet, colony_id)
            } else {
                self.resources_timer.write(mission.destination, time_now);
            }
            self.fleet_return_planet(mission.origin, f1);
            self.active_missions.write((origin, mission_id), Zeroable::zero());

            if is_colony {
                self.remove_incoming_mission(colony_mother_planet, mission_id);
            } else {
                self.remove_incoming_mission(mission.destination, mission_id);
            }

            let attacker_loss = self.calculate_fleet_loss(mission.fleet, f1);
            let defender_loss = self.calculate_fleet_loss(defender_fleet, f2);
            let defences_loss = self.calculate_defences_loss(defences, d);

            self.update_points_after_attack(origin, attacker_loss, Zeroable::zero());
            if is_colony {
                self.update_points_after_attack(colony_mother_planet, defender_loss, defences_loss);
            } else {
                self.update_points_after_attack(mission.destination, defender_loss, defences_loss);
            }
            self.last_active.write(origin, time_now);
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
                    total_loot,
                    total_debris
                );
        }

        fn recall_fleet(ref self: ContractState, mission_id: usize) {
            let origin = self.get_owned_planet(get_caller_address());
            let mission = self.active_missions.read((origin, mission_id));
            assert(!mission.is_zero(), 'no fleet to recall');
            self.fleet_return_planet(mission.origin, mission.fleet);
            self.active_missions.write((origin, mission_id), Zeroable::zero());
            self.remove_incoming_mission(mission.destination, mission_id);
            self.last_active.write(origin, get_block_timestamp());
            self
                .emit(
                    FleetReturn {
                        docked_at: origin, mission_type: mission.category, fleet: mission.fleet
                    }
                );
        }

        fn dock_fleet(ref self: ContractState, mission_id: usize) {
            let origin = self.get_owned_planet(get_caller_address());
            let mission = self.active_missions.read((origin, mission_id));
            assert(mission.category == MissionCategory::TRANSPORT, 'not a transport mission');
            assert(!mission.is_zero(), 'no fleet to dock');
            self.fleet_return_planet(mission.destination, mission.fleet);
            self.active_missions.write((origin, mission_id), Zeroable::zero());
            self.last_active.write(origin, get_block_timestamp());
            self
                .emit(
                    FleetReturn {
                        docked_at: origin, mission_type: mission.category, fleet: mission.fleet
                    }
                );
        }

        fn collect_debris(ref self: ContractState, mission_id: usize) {
            let caller = get_caller_address();
            let origin = self.get_owned_planet(caller);

            let mut mission = self.active_missions.read((origin, mission_id));
            assert(!mission.is_zero(), 'the mission is empty');
            assert(mission.category == MissionCategory::DEBRIS, 'not a debris mission');

            let time_now = get_block_timestamp();
            assert(time_now >= mission.time_arrival, 'destination not reached yet');

            let time_since_arrived = time_now - mission.time_arrival;
            let mut collector_fleet: Fleet = mission.fleet;

            if time_since_arrived > (2 * HOUR) {
                let decay_amount = fleet::calculate_fleet_loss(time_since_arrived - (2 * HOUR));
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

            self.fleet_return_planet(mission.origin, collector_fleet);
            self.active_missions.write((origin, mission_id), Zeroable::zero());
            self.last_active.write(origin, time_now);

            self
                .emit(
                    FleetReturn {
                        docked_at: origin,
                        mission_type: MissionCategory::DEBRIS,
                        fleet: mission.fleet
                    }
                );

            self
                .emit(
                    Event::DebrisCollected(
                        DebrisCollected {
                            planet_id: origin,
                            debris_field_id: mission.destination,
                            amount: collectible_debris,
                        }
                    )
                );
        }

        /////////////////////////////////////////////////////////////////////
        //                         View Functions                                
        /////////////////////////////////////////////////////////////////////
        fn get_current_planet_price(self: @ContractState) -> u128 {
            let time_elapsed = (get_block_timestamp() - self.universe_start_time.read()) / DAY;
            self.get_planet_price(time_elapsed)
        }

        fn get_number_of_planets(self: @ContractState) -> u32 {
            self.number_of_planets.read()
        }

        fn get_planet_position(self: @ContractState, planet_id: u32) -> PlanetPosition {
            self.planet_position.read(planet_id)
        }

        fn get_last_active(self: @ContractState, planet_id: u32) -> u64 {
            self.last_active.read(planet_id)
        }

        fn get_colony_mother_planet(self: @ContractState, colony_planet_id: u32) -> u32 {
            self.colony_owner.read(colony_planet_id)
        }

        fn get_planet_colonies_count(self: @ContractState, planet_id: u32) -> u8 {
            self.colony.get_planet_colony_count(planet_id)
        }

        fn get_planet_colonies(
            self: @ContractState, planet_id: u32
        ) -> Array<(u8, PlanetPosition)> {
            self.colony.get_colonies_for_planet(planet_id)
        }

        fn get_compounds_levels(self: @ContractState, planet_id: u32) -> CompoundsLevels {
            CompoundsLevels {
                steel: self.compounds_level.read((planet_id, Names::STEEL)),
                quartz: self.compounds_level.read((planet_id, Names::QUARTZ)),
                tritium: self.compounds_level.read((planet_id, Names::TRITIUM)),
                energy: self.compounds_level.read((planet_id, Names::ENERGY_PLANT)),
                lab: self.compounds_level.read((planet_id, Names::LAB)),
                dockyard: self.compounds_level.read((planet_id, Names::DOCKYARD))
            }
        }

        fn get_colony_compounds(
            self: @ContractState, planet_id: u32, colony_id: u8
        ) -> CompoundsLevels {
            self.colony.get_colony_coumpounds(planet_id, colony_id)
        }

        fn get_tech_levels(self: @ContractState, planet_id: u32) -> TechLevels {
            TechLevels {
                energy: self.techs_level.read((planet_id, Names::ENERGY_TECH)),
                digital: self.techs_level.read((planet_id, Names::DIGITAL)),
                beam: self.techs_level.read((planet_id, Names::BEAM_TECH)),
                armour: self.techs_level.read((planet_id, Names::ARMOUR)),
                ion: self.techs_level.read((planet_id, Names::ION)),
                plasma: self.techs_level.read((planet_id, Names::PLASMA_TECH)),
                weapons: self.techs_level.read((planet_id, Names::WEAPONS)),
                shield: self.techs_level.read((planet_id, Names::SHIELD)),
                spacetime: self.techs_level.read((planet_id, Names::SPACETIME)),
                combustion: self.techs_level.read((planet_id, Names::COMBUSTION)),
                thrust: self.techs_level.read((planet_id, Names::THRUST)),
                warp: self.techs_level.read((planet_id, Names::WARP)),
                exocraft: self.techs_level.read((planet_id, Names::EXOCRAFT)),
            }
        }

        fn get_debris_field(self: @ContractState, planet_id: u32) -> Debris {
            self.planet_debris_field.read(planet_id)
        }

        fn get_planet_points(self: @ContractState, planet_id: u32) -> u128 {
            self.resources_spent.read(planet_id) / 1000
        }

        fn get_spendable_resources(self: @ContractState, planet_id: u32) -> ERC20s {
            let planet_owner = self.erc721.read().ownerOf(planet_id.into());
            let steel = self.steel.read().balance_of(planet_owner).low / E18;
            let quartz = self.quartz.read().balance_of(planet_owner).low / E18;
            let tritium = self.tritium.read().balance_of(planet_owner).low / E18;
            ERC20s { steel: steel, quartz: quartz, tritium: tritium }
        }

        fn get_collectible_resources(self: @ContractState, planet_id: u32) -> ERC20s {
            self.calculate_production(planet_id)
        }

        fn get_colony_collectible_resources(
            self: @ContractState, planet_id: u32, colony_id: u8
        ) -> ERC20s {
            let uni_speed = self.uni_speed.read();
            self.colony.get_colony_resources(uni_speed, planet_id, colony_id)
        }

        fn get_ships_levels(self: @ContractState, planet_id: u32) -> Fleet {
            Fleet {
                carrier: self.ships_level.read((planet_id, Names::CARRIER)),
                scraper: self.ships_level.read((planet_id, Names::SCRAPER)),
                sparrow: self.ships_level.read((planet_id, Names::SPARROW)),
                frigate: self.ships_level.read((planet_id, Names::FRIGATE)),
                armade: self.ships_level.read((planet_id, Names::ARMADE)),
            }
        }

        fn get_colony_ships_levels(self: @ContractState, planet_id: u32, colony_id: u8) -> Fleet {
            self.colony.get_colony_ships(planet_id, colony_id)
        }

        fn get_celestia_available(self: @ContractState, planet_id: u32) -> u32 {
            self.defences_level.read((planet_id, Names::CELESTIA))
        }

        fn get_defences_levels(self: @ContractState, planet_id: u32) -> DefencesLevels {
            DefencesLevels {
                celestia: self.defences_level.read((planet_id, Names::CELESTIA)),
                blaster: self.defences_level.read((planet_id, Names::BLASTER)),
                beam: self.defences_level.read((planet_id, Names::BEAM)),
                astral: self.defences_level.read((planet_id, Names::ASTRAL)),
                plasma: self.defences_level.read((planet_id, Names::PLASMA)),
            }
        }

        fn get_colony_defences_levels(
            self: @ContractState, planet_id: u32, colony_id: u8
        ) -> DefencesLevels {
            self.colony.get_colony_defences(planet_id, colony_id)
        }

        fn is_noob_protected(self: @ContractState, planet1_id: u32, planet2_id: u32) -> bool {
            let p1_points = self.get_planet_points(planet1_id);
            let p2_points = self.get_planet_points(planet2_id);
            if p1_points > p2_points {
                return p1_points > p2_points * 5;
            } else {
                return p2_points > p1_points * 5;
            }
        }

        fn get_mission_details(self: @ContractState, planet_id: u32, mission_id: usize) -> Mission {
            self.active_missions.read((planet_id, mission_id))
        }

        fn get_active_missions(self: @ContractState, planet_id: u32) -> Array<Mission> {
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

        fn get_incoming_missions(self: @ContractState, planet_id: u32) -> Array<IncomingMission> {
            let mut arr: Array<IncomingMission> = array![];
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

        fn simulate_attack(
            self: @ContractState,
            attacker_fleet: Fleet,
            defender_fleet: Fleet,
            defences: DefencesLevels
        ) -> SimulationResult {
            let techs: TechLevels = Default::default();
            let (f1, f2, d) = fleet::war(attacker_fleet, techs, defender_fleet, defences, techs);
            let attacker_loss = self.calculate_fleet_loss(attacker_fleet, f1);
            let defender_loss = self.calculate_fleet_loss(defender_fleet, f2);
            let defences_loss = self.calculate_defences_loss(defences, d);
            SimulationResult {
                attacker_carrier: attacker_loss.carrier,
                attacker_scraper: attacker_loss.scraper,
                attacker_sparrow: attacker_loss.sparrow,
                attacker_frigate: attacker_loss.frigate,
                attacker_armade: attacker_loss.armade,
                defender_carrier: defender_loss.carrier,
                defender_scraper: defender_loss.scraper,
                defender_sparrow: defender_loss.sparrow,
                defender_frigate: defender_loss.frigate,
                defender_armade: defender_loss.armade,
                celestia: defences_loss.celestia,
                blaster: defences_loss.blaster,
                beam: defences_loss.beam,
                astral: defences_loss.astral,
                plasma: defences_loss.plasma
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn init(
            ref self: ContractState,
            erc721: ContractAddress,
            steel: ContractAddress,
            quartz: ContractAddress,
            tritium: ContractAddress,
            eth: ContractAddress,
            receiver: ContractAddress,
            uni_speed: u128,
            token_price: u128,
            is_testnet: bool
        ) {
            assert(!self.initialized.read(), 'already initialized');
            self.erc721.write(IERC721NoGameDispatcher { contract_address: erc721 });
            self.steel.write(IERC20NoGameDispatcher { contract_address: steel });
            self.quartz.write(IERC20NoGameDispatcher { contract_address: quartz });
            self.tritium.write(IERC20NoGameDispatcher { contract_address: tritium });
            self.ETH.write(IERC20CamelDispatcher { contract_address: eth });
            self.ownable.initializer(receiver);
            self.uni_speed.write(uni_speed);
            self.initialized.write(true);
            self.token_price.write(token_price);
            self.is_testnet.write(is_testnet);
        }

        fn get_position_slot_occupant(self: @ContractState, position: PlanetPosition) -> u32 {
            self.position_to_planet.read(position)
        }

        fn process_loot_payment(
            ref self: ContractState, destination_id: u32, loot_spendable: ERC20s,
        ) {
            if destination_id > 1000 {
                let colony_mother_planet = self.colony_owner.read(destination_id);
                let planet_owner = self.erc721.read().ownerOf(colony_mother_planet.into());
                self.pay_resources_erc20(planet_owner, loot_spendable);
            } else {
                self
                    .pay_resources_erc20(
                        self.erc721.read().ownerOf(destination_id.into()), loot_spendable
                    );
            }
        }

        fn get_celestia_production(self: @ContractState, planet_id: u32) -> u32 {
            let position = self.get_planet_position(planet_id);
            self.position_to_celestia_production(position.orbit)
        }

        fn get_fleet_and_defences_before_battle(
            self: @ContractState, planet_id: u32
        ) -> (Fleet, DefencesLevels, TechLevels, u32) {
            let mut fleet: Fleet = Default::default();
            let mut defences: DefencesLevels = Default::default();
            let mut techs: TechLevels = Default::default();
            let mut celestia = 0;
            if planet_id > 1000 {
                let colony_mother_planet = self.colony_owner.read(planet_id);
                defences = self
                    .get_colony_defences_levels(
                        colony_mother_planet,
                        (planet_id - colony_mother_planet * 1000).try_into().unwrap()
                    );
                techs = self.get_tech_levels(colony_mother_planet);
                celestia = defences.celestia;
            } else {
                fleet = self.get_ships_levels(planet_id);
                defences = self.get_defences_levels(planet_id);
                techs = self.get_tech_levels(planet_id);
                celestia = self.get_celestia_available(planet_id);
            }
            (fleet, defences, techs, celestia)
        }

        fn calculate_loot_amount(
            self: @ContractState, destination_id: u32, attacker_fleet: Fleet
        ) -> (ERC20s, ERC20s) {
            let mut loot_collectible: ERC20s = Default::default();
            let mut loot_spendable: ERC20s = Default::default();
            let mut storage = fleet::get_fleet_cargo_capacity(attacker_fleet);
            let mut spendable: ERC20s = Default::default();
            let mut collectible: ERC20s = Default::default();

            if destination_id > 1000 {
                let mother_planet = self.colony_owner.read(destination_id);
                let uni_speed = self.uni_speed.read();
                let colony_id: u8 = (destination_id - mother_planet * 1000).try_into().unwrap();
                collectible = self.colony.get_colony_resources(uni_speed, mother_planet, colony_id);
            } else {
                spendable = self.get_spendable_resources(destination_id);
                collectible = self.get_collectible_resources(destination_id);
            }

            if storage < (collectible.steel + collectible.quartz + collectible.tritium) {
                loot_collectible = fleet::load_resources(collectible + spendable, storage);
            } else {
                loot_collectible = fleet::load_resources(collectible, storage);

                if !spendable.is_zero() {
                    loot_spendable.steel = spendable.steel / 2;
                    loot_spendable.quartz = spendable.quartz / 2;
                    loot_spendable.tritium = spendable.tritium / 2;
                    loot_spendable =
                        fleet::load_resources(
                            loot_spendable,
                            storage
                                - (loot_collectible.steel
                                    + loot_collectible.quartz
                                    + loot_collectible.tritium)
                        );
                }
            }
            return (loot_spendable, loot_collectible);
        }

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

        fn get_owned_planet(self: @ContractState, caller: ContractAddress) -> u32 {
            let planet_id = self.erc721.read().token_of(caller);
            planet_id.low.try_into().unwrap()
        }

        fn _collect_resources(ref self: ContractState, caller: ContractAddress) {
            let planet_id = self.get_owned_planet(caller);
            assert(!planet_id.is_zero(), 'planet does not exist');
            let production = self.calculate_production(planet_id);
            self.receive_resources_erc20(caller, production);
            self.resources_timer.write(planet_id, get_block_timestamp());
        }

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

        fn calculate_production(self: @ContractState, planet_id: u32) -> ERC20s {
            let time_now = get_block_timestamp();
            let last_collection_time = self.resources_timer.read(planet_id);
            let time_elapsed = time_now - last_collection_time;
            let mines_levels = self.get_compounds_levels(planet_id);
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
            let celestia_production = self.get_celestia_production(planet_id);
            let celestia_available = self.get_celestia_available(planet_id);
            let energy_required = Consumption::base(mines_levels.steel)
                + Consumption::base(mines_levels.quartz)
                + Consumption::base(mines_levels.tritium);
            if energy_available
                + (celestia_production.into() * celestia_available).into() < energy_required {
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

        fn receive_resources_erc20(self: @ContractState, to: ContractAddress, amounts: ERC20s) {
            self.steel.read().mint(to, (amounts.steel * E18).into());
            self.quartz.read().mint(to, (amounts.quartz * E18).into());
            self.tritium.read().mint(to, (amounts.tritium * E18).into());
        }

        fn pay_resources_erc20(self: @ContractState, account: ContractAddress, amounts: ERC20s) {
            self.steel.read().burn(account, (amounts.steel * E18).into());
            self.quartz.read().burn(account, (amounts.quartz * E18).into());
            self.tritium.read().burn(account, (amounts.tritium * E18).into());
        }

        fn check_enough_resources(self: @ContractState, caller: ContractAddress, amounts: ERC20s) {
            let available: ERC20s = self.get_erc20s_available(caller);
            assert(amounts.steel <= available.steel / E18, 'Not enough steel');
            assert(amounts.quartz <= available.quartz / E18, 'Not enough quartz');
            assert(amounts.tritium <= available.tritium / E18, 'Not enough tritium');
        }

        fn update_planet_points(ref self: ContractState, planet_id: u32, spent: ERC20s) {
            self.last_active.write(planet_id, get_block_timestamp());
            self
                .resources_spent
                .write(
                    planet_id, self.resources_spent.read(planet_id) + spent.steel + spent.quartz
                );
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

        fn get_defences_cost(self: @ContractState) -> DefencesCost {
            DefencesCost {
                blaster: ERC20s { steel: 2000, quartz: 0, tritium: 0 },
                beam: ERC20s { steel: 6000, quartz: 2000, tritium: 0 },
                astral: ERC20s { steel: 20000, quartz: 15000, tritium: 2000 },
                plasma: ERC20s { steel: 50000, quartz: 50000, tritium: 30000 },
            }
        }

        fn fleet_leave_planet(ref self: ContractState, planet_id: u32, fleet: Fleet) {
            if planet_id > 500 {
                let colony_mother_planet = self.colony_owner.read(planet_id);
                self
                    .colony
                    .fleet_leaves(
                        colony_mother_planet, (planet_id % 1000).try_into().unwrap(), fleet
                    );
            } else {
                let fleet_levels = self.get_ships_levels(planet_id);
                if fleet.carrier > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::CARRIER), fleet_levels.carrier - fleet.carrier);
                }
                if fleet.scraper > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::SCRAPER), fleet_levels.scraper - fleet.scraper);
                }
                if fleet.sparrow > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::SPARROW), fleet_levels.sparrow - fleet.sparrow);
                }
                if fleet.frigate > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::FRIGATE), fleet_levels.frigate - fleet.frigate);
                }
                if fleet.armade > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::ARMADE), fleet_levels.armade - fleet.armade);
                }
            }
        }

        fn fleet_return_planet(ref self: ContractState, planet_id: u32, fleet: Fleet) {
            if planet_id > 500 {
                let colony_mother_planet = self.colony_owner.read(planet_id);
                self
                    .colony
                    .fleet_arrives(
                        colony_mother_planet, (planet_id % 1000).try_into().unwrap(), fleet
                    );
            } else {
                let fleet_levels = self.get_ships_levels(planet_id);
                if fleet.carrier > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::CARRIER), fleet_levels.carrier + fleet.carrier);
                }
                if fleet.scraper > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::SCRAPER), fleet_levels.scraper + fleet.scraper);
                }
                if fleet.sparrow > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::SPARROW), fleet_levels.sparrow + fleet.sparrow);
                }
                if fleet.frigate > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::FRIGATE), fleet_levels.frigate + fleet.frigate);
                }
                if fleet.armade > 0 {
                    self
                        .ships_level
                        .write((planet_id, Names::ARMADE), fleet_levels.armade + fleet.armade);
                }
            }
        }

        fn check_enough_ships(self: @ContractState, planet_id: u32, colony_id: u8, fleet: Fleet) {
            if colony_id == 0 {
                let ships_levels = self.get_ships_levels(planet_id);
                assert(ships_levels.carrier >= fleet.carrier, 'not enough carrier');
                assert(ships_levels.scraper >= fleet.scraper, 'not enough scrapers');
                assert(ships_levels.sparrow >= fleet.sparrow, 'not enough sparrows');
                assert(ships_levels.frigate >= fleet.frigate, 'not enough frigates');
                assert(ships_levels.armade >= fleet.armade, 'not enough armades');
            } else {
                let ships_levels = self.get_colony_ships_levels(planet_id, colony_id);
                assert(ships_levels.carrier >= fleet.carrier, 'not enough carrier');
                assert(ships_levels.scraper >= fleet.scraper, 'not enough scrapers');
                assert(ships_levels.sparrow >= fleet.sparrow, 'not enough sparrows');
                assert(ships_levels.frigate >= fleet.frigate, 'not enough frigates');
                assert(ships_levels.armade >= fleet.armade, 'not enough armades');
            }
        }

        fn update_defender_fleet_levels_after_attack(
            ref self: ContractState, planet_id: u32, f: Fleet
        ) {
            self.ships_level.write((planet_id, Names::CARRIER), f.carrier);
            self.ships_level.write((planet_id, Names::SCRAPER), f.scraper);
            self.ships_level.write((planet_id, Names::SPARROW), f.sparrow);
            self.ships_level.write((planet_id, Names::FRIGATE), f.frigate);
            self.ships_level.write((planet_id, Names::ARMADE), f.armade);
        }

        fn update_defences_after_attack(
            ref self: ContractState, planet_id: u32, d: DefencesLevels
        ) {
            self.defences_level.write((planet_id, Names::CELESTIA), d.celestia);
            self.defences_level.write((planet_id, Names::BLASTER), d.blaster);
            self.defences_level.write((planet_id, Names::BEAM), d.beam);
            self.defences_level.write((planet_id, Names::ASTRAL), d.astral);
            self.defences_level.write((planet_id, Names::PLASMA), d.plasma);
        }

        fn add_active_mission(
            ref self: ContractState, planet_id: u32, mut mission: Mission
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

        fn add_incoming_mission(ref self: ContractState, planet_id: u32, mission: IncomingMission) {
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

        fn remove_incoming_mission(ref self: ContractState, planet_id: u32, id_to_remove: usize) {
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

        fn position_to_celestia_production(self: @ContractState, orbit: u8) -> u32 {
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

        fn calculate_avg_temperature(self: @ContractState, orbit: u8) -> u32 {
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
            attacker: u32,
            attacker_position: PlanetPosition,
            attacker_initial_fleet: Fleet,
            attacker_fleet_loss: Fleet,
            defender: u32,
            defender_position: PlanetPosition,
            defender_initial_fleet: Fleet,
            defender_fleet_loss: Fleet,
            initial_defences: DefencesLevels,
            defences_loss: DefencesLevels,
            loot: ERC20s,
            debris: Debris
        ) {
            let defender = if defender > 500 {
                self.colony_owner.read(defender)
            } else {
                defender
            };
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
            ref self: ContractState, planet_id: u32, fleet: Fleet, defences: DefencesLevels
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

        fn get_fuel_consumption(
            self: @ContractState, origin: PlanetPosition, destination: PlanetPosition, fleet: Fleet
        ) -> u128 {
            let distance = fleet::get_distance(origin, destination);
            fleet::get_fuel_consumption(fleet, distance)
        }

        fn upgrade_component(
            ref self: ContractState,
            caller: ContractAddress,
            planet_id: u32,
            component: UpgradeType,
            quantity: u8
        ) -> ERC20s {
            let is_testnet = self.is_testnet.read();
            match component {
                UpgradeType::SteelMine => {
                    let current_level = self.compounds_level.read((planet_id, Names::STEEL));
                    let cost: ERC20s = CompoundCost::steel(current_level, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .compounds_level
                        .write(
                            (planet_id, Names::STEEL),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::QuartzMine => {
                    let current_level = self.compounds_level.read((planet_id, Names::QUARTZ));
                    let cost: ERC20s = CompoundCost::quartz(current_level, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .compounds_level
                        .write(
                            (planet_id, Names::QUARTZ),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::TritiumMine => {
                    let current_level = self.compounds_level.read((planet_id, Names::TRITIUM));
                    let cost: ERC20s = CompoundCost::tritium(current_level, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .compounds_level
                        .write(
                            (planet_id, Names::TRITIUM),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::EnergyPlant => {
                    let current_level = self.compounds_level.read((planet_id, Names::ENERGY_PLANT));
                    let cost: ERC20s = CompoundCost::energy(current_level, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .compounds_level
                        .write(
                            (planet_id, Names::ENERGY_PLANT),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Lab => {
                    let current_level = self.compounds_level.read((planet_id, Names::LAB));
                    let cost: ERC20s = CompoundCost::lab(current_level, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .compounds_level
                        .write(
                            (planet_id, Names::LAB),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Dockyard => {
                    let current_level = self.compounds_level.read((planet_id, Names::DOCKYARD));
                    let cost: ERC20s = CompoundCost::dockyard(current_level, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .compounds_level
                        .write(
                            (planet_id, Names::DOCKYARD),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::EnergyTech => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::energy_innovation_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().energy;
                    let cost = Lab::get_tech_cost(techs.energy, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::ENERGY_TECH),
                            techs.energy + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Digital => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::digital_systems_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().digital;
                    let cost = Lab::get_tech_cost(techs.digital, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::DIGITAL),
                            techs.digital + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::BeamTech => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::beam_technology_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().beam;
                    let cost = Lab::get_tech_cost(techs.beam, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::BEAM_TECH),
                            techs.beam + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Armour => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::armour_innovation_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().armour;
                    let cost = Lab::get_tech_cost(techs.armour, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::ARMOUR),
                            techs.armour + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Ion => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::ion_systems_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().ion;
                    let cost = Lab::get_tech_cost(techs.ion, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::ION),
                            techs.ion + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::PlasmaTech => {
                    assert!(!is_testnet, "NoGame: Plasma tech not available on testnet realease");
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::plasma_engineering_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().plasma;
                    let cost = Lab::get_tech_cost(techs.plasma, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::PLASMA_TECH),
                            techs.plasma + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Weapons => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::weapons_development_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().weapons;
                    let cost = Lab::get_tech_cost(techs.weapons, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::WEAPONS),
                            techs.weapons + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Shield => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::shield_tech_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().shield;
                    let cost = Lab::get_tech_cost(techs.shield, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::SHIELD),
                            techs.shield + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Spacetime => {
                    assert!(!is_testnet, "NoGame: Space tech not available on testnet realease");
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::spacetime_warp_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().spacetime;
                    let cost = Lab::get_tech_cost(techs.spacetime, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::SPACETIME),
                            techs.spacetime + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Combustion => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::combustive_engine_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().combustion;
                    let cost = Lab::get_tech_cost(techs.combustion, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::COMBUSTION),
                            techs.combustion + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Thrust => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::thrust_propulsion_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().thrust;
                    let cost = Lab::get_tech_cost(techs.thrust, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::THRUST),
                            techs.thrust + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Warp => {
                    assert!(!is_testnet, "NoGame: Warp tech not available on testnet realease");
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::warp_drive_requirements_check(lab_level, techs);
                    let base_cost: ERC20s = Lab::base_tech_costs().warp;
                    let cost = Lab::get_tech_cost(techs.warp, quantity, base_cost);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::WARP),
                            techs.warp + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
                UpgradeType::Exocraft => {
                    let lab_level = self.compounds_level.read((planet_id, Names::LAB));
                    let techs = self.get_tech_levels(planet_id);
                    Lab::exocraft_requirements_check(lab_level, techs);
                    let cost = Lab::exocraft_cost(techs.exocraft, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .techs_level
                        .write(
                            (planet_id, Names::EXOCRAFT),
                            techs.exocraft + quantity.try_into().expect('u32 into u8 failed')
                        );
                    return cost;
                },
            }
        }

        fn build_component(
            ref self: ContractState,
            caller: ContractAddress,
            planet_id: u32,
            dockyard_level: u8,
            techs: TechLevels,
            component: BuildType,
            quantity: u32
        ) -> ERC20s {
            let is_testnet = self.is_testnet.read();
            match component {
                BuildType::Carrier => {
                    let techs = self.get_tech_levels(planet_id);
                    Dockyard::carrier_requirements_check(dockyard_level, techs);
                    let cost = Dockyard::get_ships_cost(quantity, self.get_ships_cost().carrier);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .ships_level
                        .write(
                            (planet_id, Names::CARRIER),
                            self.ships_level.read((planet_id, Names::CARRIER)) + quantity
                        );
                    return cost;
                },
                BuildType::Scraper => {
                    let techs = self.get_tech_levels(planet_id);
                    Dockyard::scraper_requirements_check(dockyard_level, techs);
                    let cost = Dockyard::get_ships_cost(quantity, self.get_ships_cost().scraper);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .ships_level
                        .write(
                            (planet_id, Names::SCRAPER),
                            self.ships_level.read((planet_id, Names::SCRAPER)) + quantity
                        );
                    return cost;
                },
                BuildType::Celestia => {
                    let techs = self.get_tech_levels(planet_id);
                    Dockyard::celestia_requirements_check(dockyard_level, techs);
                    let cost = Dockyard::get_ships_cost(quantity, self.get_ships_cost().celestia);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .defences_level
                        .write(
                            (planet_id, Names::CELESTIA),
                            self.defences_level.read((planet_id, Names::CELESTIA)) + quantity
                        );
                    return cost;
                },
                BuildType::Sparrow => {
                    let techs = self.get_tech_levels(planet_id);
                    Dockyard::sparrow_requirements_check(dockyard_level, techs);
                    let cost = Dockyard::get_ships_cost(quantity, self.get_ships_cost().sparrow);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .ships_level
                        .write(
                            (planet_id, Names::SPARROW),
                            self.ships_level.read((planet_id, Names::SPARROW)) + quantity
                        );
                    return cost;
                },
                BuildType::Frigate => {
                    let techs = self.get_tech_levels(planet_id);
                    Dockyard::frigate_requirements_check(dockyard_level, techs);
                    let cost = Dockyard::get_ships_cost(quantity, self.get_ships_cost().frigate);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .ships_level
                        .write(
                            (planet_id, Names::FRIGATE),
                            self.ships_level.read((planet_id, Names::FRIGATE)) + quantity
                        );
                    return cost;
                },
                BuildType::Armade => {
                    assert!(!is_testnet, "NoGame: Armade not available on testnet realease");
                    let techs = self.get_tech_levels(planet_id);
                    Dockyard::armade_requirements_check(dockyard_level, techs);
                    let cost = Dockyard::get_ships_cost(quantity, self.get_ships_cost().armade);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .ships_level
                        .write(
                            (planet_id, Names::ARMADE),
                            self.ships_level.read((planet_id, Names::ARMADE)) + quantity
                        );
                    return cost;
                },
                BuildType::Blaster => {
                    let techs = self.get_tech_levels(planet_id);
                    Defences::blaster_requirements_check(dockyard_level, techs);
                    let cost = Defences::get_defences_cost(
                        quantity, self.get_defences_cost().blaster
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .defences_level
                        .write(
                            (planet_id, Names::BLASTER),
                            self.defences_level.read((planet_id, Names::BLASTER)) + quantity
                        );
                    return cost;
                },
                BuildType::Beam => {
                    let techs = self.get_tech_levels(planet_id);
                    Defences::beam_requirements_check(dockyard_level, techs);
                    let cost = Defences::get_defences_cost(quantity, self.get_defences_cost().beam);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .defences_level
                        .write(
                            (planet_id, Names::BEAM),
                            self.defences_level.read((planet_id, Names::BEAM)) + quantity
                        );
                    return cost;
                },
                BuildType::Astral => {
                    assert!(!is_testnet, "NoGame: Astral not available on testnet realease");
                    let techs = self.get_tech_levels(planet_id);
                    Defences::astral_launcher_requirements_check(dockyard_level, techs);
                    let cost = Defences::get_defences_cost(
                        quantity, self.get_defences_cost().astral
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .defences_level
                        .write(
                            (planet_id, Names::ASTRAL),
                            self.defences_level.read((planet_id, Names::ASTRAL)) + quantity
                        );
                    return cost;
                },
                BuildType::Plasma => {
                    assert!(!is_testnet, "NoGame: Plasma Cannon not available on testnet realease");
                    let techs = self.get_tech_levels(planet_id);
                    Defences::plasma_beam_requirements_check(dockyard_level, techs);
                    let cost = Defences::get_defences_cost(
                        quantity, self.get_defences_cost().plasma
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .defences_level
                        .write(
                            (planet_id, Names::PLASMA),
                            self.defences_level.read((planet_id, Names::PLASMA)) + quantity
                        );
                    return cost;
                },
            }
        }

        fn upgrade_colony_component(
            ref self: ContractState,
            caller: ContractAddress,
            planet_id: u32,
            colony_id: u8,
            component: ColonyUpgradeType,
            quantity: u8
        ) -> ERC20s {
            let levels = self.colony.get_colony_coumpounds(planet_id, colony_id);
            match component {
                ColonyUpgradeType::SteelMine => {
                    let cost: ERC20s = CompoundCost::steel(levels.steel, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_compound_upgrade(
                            planet_id, colony_id, ColonyUpgradeType::SteelMine, quantity
                        );
                    return cost;
                },
                ColonyUpgradeType::QuartzMine => {
                    let cost: ERC20s = CompoundCost::quartz(levels.quartz, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_compound_upgrade(
                            planet_id, colony_id, ColonyUpgradeType::QuartzMine, quantity
                        );
                    return cost;
                },
                ColonyUpgradeType::TritiumMine => {
                    let cost: ERC20s = CompoundCost::tritium(levels.tritium, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_compound_upgrade(
                            planet_id, colony_id, ColonyUpgradeType::TritiumMine, quantity
                        );
                    return cost;
                },
                ColonyUpgradeType::EnergyPlant => {
                    let cost: ERC20s = CompoundCost::energy(levels.energy, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_compound_upgrade(
                            planet_id, colony_id, ColonyUpgradeType::EnergyPlant, quantity
                        );
                    return cost;
                },
                ColonyUpgradeType::Dockyard => {
                    let cost: ERC20s = CompoundCost::dockyard(levels.dockyard, quantity);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_compound_upgrade(
                            planet_id, colony_id, ColonyUpgradeType::Dockyard, quantity
                        );
                    return cost;
                },
            }
        }

        fn build_colony_component(
            ref self: ContractState,
            caller: ContractAddress,
            planet_id: u32,
            colony_id: u8,
            component: ColonyBuildType,
            quantity: u32
        ) -> ERC20s {
            let techs = self.get_tech_levels(planet_id);
            let is_testnet = self.is_testnet.read();
            match component {
                ColonyBuildType::Carrier => {
                    let cost: ERC20s = Dockyard::get_ships_cost(
                        quantity, self.get_ships_cost().carrier
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Carrier,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Scraper => {
                    let cost: ERC20s = Dockyard::get_ships_cost(
                        quantity, self.get_ships_cost().scraper
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Scraper,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Sparrow => {
                    let cost: ERC20s = Dockyard::get_ships_cost(
                        quantity, self.get_ships_cost().sparrow
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Sparrow,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Frigate => {
                    let cost: ERC20s = Dockyard::get_ships_cost(
                        quantity, self.get_ships_cost().frigate
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Frigate,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Armade => {
                    let cost: ERC20s = Dockyard::get_ships_cost(
                        quantity, self.get_ships_cost().armade
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Armade,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Celestia => {
                    let cost: ERC20s = Dockyard::get_ships_cost(
                        quantity, self.get_ships_cost().celestia
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Celestia,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Blaster => {
                    let cost = Defences::get_defences_cost(
                        quantity, self.get_defences_cost().blaster
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Blaster,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Beam => {
                    let cost = Defences::get_defences_cost(quantity, self.get_defences_cost().beam);
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id, colony_id, techs, ColonyBuildType::Beam, quantity, is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Astral => {
                    let cost = Defences::get_defences_cost(
                        quantity, self.get_defences_cost().astral
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Astral,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
                ColonyBuildType::Plasma => {
                    let cost = Defences::get_defences_cost(
                        quantity, self.get_defences_cost().plasma
                    );
                    self.check_enough_resources(caller, cost);
                    self.pay_resources_erc20(caller, cost);
                    self
                        .colony
                        .process_colony_unit_build(
                            planet_id,
                            colony_id,
                            techs,
                            ColonyBuildType::Plasma,
                            quantity,
                            is_testnet
                        );
                    return cost;
                },
            }
        }
    }
}

