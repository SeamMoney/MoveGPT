module aptos_blog_demo::blog_state_update_logic {
    use aptos_blog_demo::blog_state;
    use aptos_blog_demo::blog_state_updated;
    use std::string::String;
    use aptos_blog_demo::genesis_account;

    friend aptos_blog_demo::blog_state_aggregate;

    public(friend) fun verify(
        account: &signer,
        name: String,
        articles: vector<u128>,
        is_emergency: bool,
        blog_state: &blog_state::BlogState,
    ): blog_state::BlogStateUpdated {
        genesis_account::assert_genesis_account(account);
        blog_state::new_blog_state_updated(
            blog_state,
            name,
            articles,
            is_emergency,
        )
    }

    public(friend) fun mutate(
        _account: &signer,
        blog_state_updated: &blog_state::BlogStateUpdated,
        blog_state: blog_state::BlogState,
    ): blog_state::BlogState {
        let name = blog_state_updated::name(blog_state_updated);
        let articles = blog_state_updated::articles(blog_state_updated);
        let is_emergency = blog_state_updated::is_emergency(blog_state_updated);
        blog_state::set_name(&mut blog_state, name);
        blog_state::set_articles(&mut blog_state, articles);
        blog_state::set_is_emergency(&mut blog_state, is_emergency);
        blog_state
    }

}
