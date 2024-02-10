module coin_x_oracle::pyth {
  // === Imports ===
  use std::type_name;
  
  use sui::sui::SUI;
  use sui::math::pow;
  use sui::object::ID;
  use sui::coin::Coin;
  use sui::clock::Clock;
  use sui::dynamic_field as df;

  use suitears::owner::OwnerCap;
  use suitears::oracle::{Self, Oracle, Request};  
  use suitears::math256::{mul_div_down, div_up};

  use wormhole::vaa::{parse_and_verify};  
  use wormhole::state::{State as WormholeState};

  use pyth::i64;
  use pyth::hot_potato_vector;
  use pyth::state::{State as PythState};
  use pyth::price::{Self as pyth_price};
  use pyth::price_info::{Self, PriceInfoObject};
  use pyth::pyth::{get_price as pyth_get_price, create_price_infos_hot_potato, update_single_price_feed};

  // === Errors ===

  const EInvalidPriceObjectInfo: u64 = 0;
  const ENegativePrice: u64 = 1;
  const EPriceConfidenceOutOfRange: u64 = 2;

  // === Constants ===

  const POW_10_18: u256 = 1000000000000000000; // 1e18

  // === Structs ===

  struct PriceInfoObjectKey has copy, drop, store {}

  struct PythFeed has drop {}

  // === Public-Mutative Functions ===

  /*
  * @notice Adds the Switchboard feed to the `oracle`.  
  *
  * @param self The `Oracle` that will support Switchboard.    
  * @param cap The `suitears::owner::OwnerCap` of `self`.   
  * @param price_info_object The Pyth Network Price Info Object Id that will be associated with a price feed.
  */
  public fun new<Witness: drop>(oracle: &mut Oracle<Witness>, cap: &OwnerCap<Witness>, price_info_object: &PriceInfoObject) {
    oracle::add(oracle, cap, type_name::get<PythFeed>());
    let uid = oracle::uid_mut(oracle, cap);
    df::add(uid, PriceInfoObjectKey {}, price_info::uid_to_inner(price_info_object));
  }  

  public fun report<Witness: drop>(
    oracle: &Oracle<Witness>, 
    request: &mut Request, 
    wormhole_state: &WormholeState,
    pyth_state: &PythState,
    buf: vector<u8>,
    price_info_object: &mut PriceInfoObject,
    pyth_fee: Coin<SUI>,
    clock_object: &Clock,
    witness: Witness
  ) {
    let whitelisted_id = *df::borrow<PriceInfoObjectKey, ID>(oracle::uid(oracle), PriceInfoObjectKey {});

    assert!(whitelisted_id == price_info::uid_to_inner(price_info_object), EInvalidPriceObjectInfo);
    
    let vaa = parse_and_verify(wormhole_state, buf, clock_object);

    let hot_potato_vector = update_single_price_feed(
      pyth_state,
      create_price_infos_hot_potato(pyth_state, vector[vaa], clock_object),
      price_info_object,
      pyth_fee,
      clock_object
    );
    
    hot_potato_vector::destroy(hot_potato_vector);

    // Get the price raw value, exponent and timestamp
    let pyth_price = pyth_get_price(pyth_state, price_info_object, clock_object);
    let pyth_price_value = pyth_price::get_price(&pyth_price);
    let pyth_price_expo = pyth_price::get_expo(&pyth_price);
    let latest_timestamp = pyth_price::get_timestamp(&pyth_price);
    let price_conf = pyth_price::get_conf(&pyth_price);

    let pyth_price_u64 = i64::get_magnitude_if_positive(&pyth_price_value);

    assert_price_conf(pyth_price_u64, price_conf);

    assert!(pyth_price_u64 != 0, ENegativePrice);

    let is_exponent_negative = i64::get_is_negative(&pyth_price_expo);
    
    let pyth_exp_u64 = if (is_exponent_negative) 
      i64::get_magnitude_if_negative(&pyth_price_expo) 
    else 
      i64::get_magnitude_if_positive(&pyth_price_expo);

    let value = if (is_exponent_negative) 
      mul_div_down((pyth_price_u64 as u256), POW_10_18, (pow(10, (pyth_exp_u64 as u8)) as u256))
    else 
      (pyth_price_u64 as u256)  * (pow(10, 18 - (pyth_exp_u64 as u8)) as u256);

    oracle::report(request, witness, latest_timestamp, (value as u128), 18);
  }  

  // === Private Functions ===
  
  fun assert_price_conf(price_value: u64, price_conf: u64) {
    let base = 10000;
    let price_conf_range = 2 * base; // 2% of price
    let price_conf_diff = div_up((price_conf as u256) * base * 100, (price_value as u256));
    assert!(price_conf_range >= price_conf_diff, EPriceConfidenceOutOfRange);
  }  
}