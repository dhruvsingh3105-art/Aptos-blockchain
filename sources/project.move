module MyModule::WaitlistFutures {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    /// Struct representing a waitlist position token
    struct WaitlistToken has store, key {
        course_id: u64,           // Unique course identifier
        position: u64,            // Position in waitlist (1 = first)
        deposit_amount: u64,      // Amount paid for the position
        original_holder: address, // Original purchaser for refund tracking
        is_enrolled: bool,        // Whether position holder enrolled
    }

    /// Struct to manage course waitlist and hold deposits
    struct CourseWaitlist has store, key {
        course_id: u64,
        total_positions: u64,
        deposit_pool: u64,        // Total deposits held for refunds
    }

    /// Function to purchase a waitlist position token
    public fun purchase_waitlist_position(
        buyer: &signer, 
        course_owner: address, 
        course_id: u64, 
        deposit_amount: u64
    ) acquires CourseWaitlist {
        let buyer_addr = signer::address_of(buyer);
        let course = borrow_global_mut<CourseWaitlist>(course_owner);
        
        // Transfer deposit to course owner's deposit pool
        let payment = coin::withdraw<AptosCoin>(buyer, deposit_amount);
        coin::deposit<AptosCoin>(course_owner, payment);
        
        // Create waitlist token for the buyer
        let new_position = course.total_positions + 1;
        let waitlist_token = WaitlistToken {
            course_id,
            position: new_position,
            deposit_amount,
            original_holder: buyer_addr,
            is_enrolled: false,
        };
        
        // Update course data
        course.total_positions = new_position;
        course.deposit_pool = course.deposit_pool + deposit_amount;
        
        // Store token with buyer
        move_to(buyer, waitlist_token);
    }

    /// Function to process enrollment and refund (called by course owner)
    public fun process_enrollment_refund(
        course_owner: &signer,
        token_holder: address
    ) acquires WaitlistToken, CourseWaitlist {
        let course = borrow_global_mut<CourseWaitlist>(signer::address_of(course_owner));
        let token = borrow_global_mut<WaitlistToken>(token_holder);
        
        assert!(!token.is_enrolled, 1); // Ensure not already enrolled
        
        // Mark as enrolled
        token.is_enrolled = true;
        
        // Process refund to original holder
        let refund_amount = token.deposit_amount;
        let refund = coin::withdraw<AptosCoin>(course_owner, refund_amount);
        coin::deposit<AptosCoin>(token.original_holder, refund);
        
        // Update deposit pool
        course.deposit_pool = course.deposit_pool - refund_amount;
    }
}