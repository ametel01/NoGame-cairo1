#[starknet::interface]
trait IERC721NGMetadata<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn token_uri(self: @TState, token_id: u256) -> Array<felt252>;
}

#[starknet::interface]
trait IERC721NGMetadataCamelOnly<TState> {
    fn tokenURI(self: @TState, tokenId: u256) -> Array<felt252>;
}
