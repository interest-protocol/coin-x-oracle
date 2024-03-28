module coin_x_oracle::pyth_oracle {
  // === Imports ===
  use std::type_name;
  
  use sui::object;
  use sui::math::pow;
  use sui::object::ID;
  use sui::clock::Clock;
  use sui::dynamic_field as df;

  use suitears::fixed_point_wad;
  use suitears::math256::mul_div_down;
  use suitears::owner::{Self, OwnerCap};
  use suitears::oracle::{Self, Oracle, Request};  

  use pyth::i64;
  use pyth::state::State as PythState;
  use pyth::price::Self as pyth_price;
  use pyth::pyth::get_price as pyth_get_price;
  use pyth::price_info::{Self, PriceInfoObject};

  // === Errors ===

  const EInvalidPriceObjectInfo: u64 = 0;
  const EZeroPrice: u64 = 1;
  const EPriceConfidenceOutOfRange: u64 = 2;

  // === Constants ===

  const POW_10_18: u256 = 1000000000000000000; // 1e18
  const TWO_PERCENT: u256 = 20000000000000000; // 0.02e18
  const HUNDRED_PERCENT: u256 = 1000000000000000000; // 1e18
  const TIME_SCALAR: u64 = 1000;

  // === Structs ===

  struct PriceInfoObjectKey has copy, drop, store {}

  struct ConfidenceKey has copy, drop, store {}

  struct PythFeed has drop {}

  // === Public-Mutative Functions ===

  /*
  * @notice Adds a `PythFeed` report to a `suitears::oracle::Request`.  
  *
  * @param self A `suiterars::oracle::Oracle` with this module's witness.    
  * @param request A hot potato issued from the `self` to create a `suiterars::oracle::Price`.  
  * @param wormhole_state The state of the Wormhole module on Sui.
  * @param pyth_state The state of the Pyth module on Sui.
  * @param price_info_object An object that contains price information. One per asset.
  * @param clock_object The shared Clock object from Sui.
  *
  * aborts-if:    
  * - The `price_info_object` is not whitelisted.   
  * - The price confidence is out of range.  
  * - The price is negative or zero.   
  */
  public fun report<Witness: drop>(
    oracle: &Oracle<Witness>, 
    request: &mut Request, 
    pyth_state: &PythState,
    price_info_object: &mut PriceInfoObject,
    clock_object: &Clock
  ) {
    let whitelisted_id = *df::borrow<PriceInfoObjectKey, ID>(oracle::uid(oracle), PriceInfoObjectKey {});

    assert!(whitelisted_id == price_info::uid_to_inner(price_info_object), EInvalidPriceObjectInfo);

    // Get the price raw value, exponent and timestamp
    let pyth_price = pyth_get_price(pyth_state, price_info_object, clock_object);
    let pyth_price_value = pyth_price::get_price(&pyth_price);
    let pyth_price_expo = pyth_price::get_expo(&pyth_price);
    let latest_timestamp = pyth_price::get_timestamp(&pyth_price);
    let price_conf = pyth_price::get_conf(&pyth_price);

    let pyth_price_u64 = i64::get_magnitude_if_positive(&pyth_price_value);

    assert_price_conf(oracle, pyth_price_u64, price_conf);

    assert!(pyth_price_u64 != 0, EZeroPrice);

    let is_exponent_negative = i64::get_is_negative(&pyth_price_expo);
    
    let pyth_exp_u64 = if (is_exponent_negative) 
      i64::get_magnitude_if_negative(&pyth_price_expo) 
    else 
      i64::get_magnitude_if_positive(&pyth_price_expo);

    let value = if (is_exponent_negative) 
      mul_div_down((pyth_price_u64 as u256), POW_10_18, (pow(10, (pyth_exp_u64 as u8)) as u256))
    else 
      (pyth_price_u64 as u256)  * (pow(10, 18 - (pyth_exp_u64 as u8)) as u256);

    oracle::report(request, PythFeed {}, latest_timestamp * TIME_SCALAR, (value as u128), 18);
  }  

  // === Admin Functions ===  

  /*
  * @notice Adds the `PythFeed` feed to the `oracle`.  
  *
  * @dev By default, this oracle will require prices to have a confidence level of 98% or higher.
  * 
  * @param self The `suiterars::oracle::Oracle` that will require a Pyth report.     
  * @param cap The `suitears::owner::OwnerCap` of `self`.   
  * @param price_info_object This Pyth Network Price Info Object will be whitelisted.
  */
  public fun add<Witness: drop>(oracle: &mut Oracle<Witness>, cap: &OwnerCap<Witness>, price_info_object: &PriceInfoObject) {
    oracle::add(oracle, cap, type_name::get<PythFeed>());
    let uid = oracle::uid_mut(oracle, cap);
    df::add(uid, PriceInfoObjectKey {}, price_info::uid_to_inner(price_info_object));
    df::add(uid, ConfidenceKey {}, TWO_PERCENT);
  }  

  /*
  * @notice Updates the required confidence interval percentage for the `self`.  
  * 
  * @dev Note that you can add a confidence interval percentage of 0%. We recommend a value higher than 95%.
  *
  * @param self The `suiterars::oracle::Oracle` that will require a Pyth report.     
  * @param cap The `suitears::owner::OwnerCap` of `self`.   
  * @param conf The new confidence.
  *
  * aborts-if 
  * - The `cap` does not own the `self`.
  * - The `conf` is higher than 100%.
  */
  public fun update_confidence<Witness: drop>(oracle: &mut Oracle<Witness>, cap: &OwnerCap<Witness>, conf: u256) {
    owner::assert_ownership(cap, object::id(oracle));
    let saved_conf = df::borrow_mut<ConfidenceKey, u256>(oracle::uid_mut(oracle, cap), ConfidenceKey {});
    *saved_conf = HUNDRED_PERCENT - conf;
  }

  // === Private Functions ===
  
  /*
  * @notice Ensures that we are reporting a price within the required confidence interval. 
  *
  * @dev Read about price confidence intervals here: https://docs.pyth.network/price-feeds/pythnet-price-feeds/best-practices
  *
  * @param self The `suiterars::oracle::Oracle` that contains the required confidence percentage.   
  * @param price_value The price
  * @param price_conf The confidence interval for the `price_value`
  *
  * aborts-if:  
  * - The `price_value`'s confidence interval is lower than the `oracle` allows. 
  */
  fun assert_price_conf<Witness: drop>(oracle: &Oracle<Witness>, price_value: u64, price_conf: u64) {
    let price_conf_percentage = fixed_point_wad::div_up((price_conf as u256), (price_value as u256));
    let required_conf = *df::borrow<ConfidenceKey, u256>(oracle::uid(oracle), ConfidenceKey {});
    assert!(required_conf >= price_conf_percentage, EPriceConfidenceOutOfRange);
  }  
}