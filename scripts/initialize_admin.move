script {
    use TokenDaysDestroyedStaking;

    fun main(admin: &signer) {
        // Initialize the admin account
        TokenDaysDestroyedStaking::initialize_admin(admin);
    }
}
