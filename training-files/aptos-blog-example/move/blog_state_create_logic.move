module aptos_blog_demo::blog_state_create_logic {
    use aptos_blog_demo::blog_state;
    use aptos_blog_demo::blog_state_created;
    use std::string::String;
    use std::vector;
    use aptos_blog_demo::genesis_account;

    friend aptos_blog_demo::blog_state_aggregate;

    public(friend) fun verify(
        account: &signer,
        name: String,
        is_emergency: bool,
    ): blog_state::BlogStateCreated {
        genesis_account::assert_genesis_account(account);
        blog_state::new_blog_state_created(
            name,
            is_emergency,
        )
    }

    public(friend) fun mutate(
        _account: &signer,
        blog_state_created: &blog_state::BlogStateCreated,
    ): blog_state::BlogState {
        let name = blog_state_created::name(blog_state_created);
        let is_emergency = blog_state_created::is_emergency(blog_state_created);
        blog_state::new_blog_state(
            name,
            vector::empty(),
            is_emergency,
        )
    }

}
