
module kari::kari {
    use std::option;

    use sui::object::{Self, UID, ID};
    use sui::tx_context::{TxContext};
    use sui::balance::{Self, Supply};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::url;
    use sui::vec_set::{Self, VecSet};
    use sui::tx_context;
    use sui::package::{Publisher};
    use sui::event::{emit};

    const KARI_PRE_MINT_AMOUNT: u64 = 10000000000000000; // 600M 60% of the supply

    // Errors
    const ERROR_NOT_ALLOWED_TO_MINT: u64 = 1;
    const ERROR_NO_ZERO_ADDRESS: u64 = 2;

    struct KARI has drop {}

    struct KARIStorage has key {
        id: UID,
        supply: Supply<KARI>,
        minters: VecSet<ID> // List of publishers that are allowed to mint KARI
    }

    struct KARIAdminCap has key {
        id: UID
    }

    // Events
    struct MinterAdded has copy, drop {
        id: ID
    }

    struct MinterRemoved has copy, drop {
        id: ID
    }

    struct NewAdmin has copy, drop {
        admin: address
    }

    fun init(witness: KARI, ctx: &mut TxContext) {
        // Create the KARI governance token with 9 decimals
        let (treasury, metadata) = coin::create_currency<KARI>(
            witness,
            9,
            b"KARI",
            b"Kanari Network Token",
            b"The governance token of Kanari Network",
            option::some(url::new_unsafe_from_bytes(b"https://avatars.githubusercontent.com/u/127471673?v=4")),
            ctx
        );
        // Transform the treasury_cap into a supply struct to allow this contract to mint/burn DNR
        let supply = coin::treasury_into_supply(treasury);

        // Pre-mint 60% of the supply to distribute
        transfer::public_transfer(
            coin::from_balance(
                balance::increase_supply(&mut supply, KARI_PRE_MINT_AMOUNT), ctx
            ),
            tx_context::sender(ctx)
        );

        transfer::transfer(
            KARIAdminCap {
                id: object::new(ctx)
            },
            tx_context::sender(ctx)
        );

        transfer::share_object(
            KARIStorage {
                id: object::new(ctx),
                supply,
                minters: vec_set::empty()
            }
        );

        // Freeze the metadata object
        transfer::public_freeze_object(metadata);
    }

    /**
    * @dev Only minters can create new Coin<KARI>
    * @param storage The KARIStorage
    * @param publisher The Publisher object of the package who wishes to mint KARI
    * @return Coin<KARI> New created KARI coin
    */
    public fun mint(storage: &mut KARIStorage, publisher: &Publisher, value: u64, ctx: &mut TxContext): Coin<KARI> {
        assert!(is_minter(storage, object::id(publisher)), ERROR_NOT_ALLOWED_TO_MINT);

        coin::from_balance(balance::increase_supply(&mut storage.supply, value), ctx)
    }

    /**
    * @dev This function allows anyone to burn their own KARI.
    * @param storage The KARIStorage shared object
    * @param c The KARI coin that will be burned
    */
    public fun burn(storage: &mut KARIStorage, c: Coin<KARI>): u64 {
        balance::decrease_supply(&mut storage.supply, coin::into_balance(c))
    }

    /**
    * @dev A utility function to transfer KARI to a {recipient}
    * @param c The Coin<KARI> to transfer
    * @param recipient The recipient of the Coin<IPX>
    */
    public entry fun transfer(c: coin::Coin<KARI>, recipient: address) {
        transfer::public_transfer(c, recipient);
    }

    /**
    * @dev It returns the total supply of the Coin<X>
    * @param storage The {KARIStorage} shared object
    * @return the total supply in u64
    */
    public fun total_supply(storage: &KARIStorage): u64 {
        balance::supply_value(&storage.supply)
    }


    /**
    * @dev It allows the holder of the {KARIAdminCap} to add a minter.
    * @param _ The KARIAdminCap to guard this function
    * @param storage The KARIStorage shared object
    * @param publisher The package that owns this publisher will be able to mint IPX
    *
    * It emits the MinterAdded event with the {ID} of the {Publisher}
    *
    */
    entry public fun add_minter(_: &KARIAdminCap, storage: &mut KARIStorage, id: ID) {
        vec_set::insert(&mut storage.minters, id);
        emit(
            MinterAdded {
                id
            }
        );
    }

    /**
    * @dev It allows the holder of the {KARIAdminCap} to remove a minter.
    * @param _ The KARIAdminCap to guard this function
    * @param storage The KARIStorage shared object
    * @param publisher The package that will no longer be able to mint KARI
    *
    * It emits the  MinterRemoved event with the {ID} of the {Publisher}
    *
    */
    entry public fun remove_minter(_: &KARIAdminCap, storage: &mut KARIStorage, id: ID) {
        vec_set::remove(&mut storage.minters, &id);
        emit(
            MinterRemoved {
                id
            }
        );
    }


    /**
    * @dev It gives the admin rights to the recipient.
    * @param admin_cap The KARIAdminCap that will be transferred
    * @recipient the new admin address
    *
    * It emits the NewAdmin event with the new admin address
    *
    */
    entry public fun transfer_admin(admin_cap: KARIAdminCap, recipient: address) {
        assert!(recipient != @0x0, ERROR_NO_ZERO_ADDRESS);
        transfer::transfer(admin_cap, recipient);

        emit(NewAdmin {
            admin: recipient
        });
    }

    /**
    * @dev It indicates if a package has the right to mint KARI
    * @param storage The KARIStorage shared object
    * @param publisher of the package
    * @return bool true if it can mint KARI
    */
    public fun is_minter(storage: &KARIStorage, id: ID): bool {
        vec_set::contains(&storage.minters, &id)
    }


    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(KARI {}, ctx);
    }
}