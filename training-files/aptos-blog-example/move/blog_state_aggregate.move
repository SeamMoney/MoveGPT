// <autogenerated>
//   This file was generated by dddappp code generator.
//   Any changes made to this file manually will be lost next time the file is regenerated.
// </autogenerated>

module aptos_blog_demo::blog_state_aggregate {
    use aptos_blog_demo::blog_state;
    use aptos_blog_demo::blog_state_add_article_logic;
    use aptos_blog_demo::blog_state_create_logic;
    use aptos_blog_demo::blog_state_delete_logic;
    use aptos_blog_demo::blog_state_remove_article_logic;
    use aptos_blog_demo::blog_state_update_logic;
    use std::string::String;

    friend aptos_blog_demo::article_create_logic;
    friend aptos_blog_demo::article_delete_logic;

    public entry fun create(
        account: &signer,
        name: String,
        is_emergency: bool,
    ) {
        let blog_state_created = blog_state_create_logic::verify(
            account,
            name,
            is_emergency,
        );
        let blog_state = blog_state_create_logic::mutate(
            account,
            &blog_state_created,
        );
        blog_state::add_blog_state(blog_state);
        blog_state::emit_blog_state_created(blog_state_created);
    }

    public(friend) fun add_article(
        article_id: u128,
    ) {
        let blog_state = blog_state::remove_blog_state();
        let article_added_to_blog = blog_state_add_article_logic::verify(
            article_id,
            &blog_state,
        );
        let updated_blog_state = blog_state_add_article_logic::mutate(
            &article_added_to_blog,
            blog_state,
        );
        blog_state::update_version_and_add(updated_blog_state);
        blog_state::emit_article_added_to_blog(article_added_to_blog);
    }

    public(friend) fun remove_article(
        article_id: u128,
    ) {
        let blog_state = blog_state::remove_blog_state();
        let article_removed_from_blog = blog_state_remove_article_logic::verify(
            article_id,
            &blog_state,
        );
        let updated_blog_state = blog_state_remove_article_logic::mutate(
            &article_removed_from_blog,
            blog_state,
        );
        blog_state::update_version_and_add(updated_blog_state);
        blog_state::emit_article_removed_from_blog(article_removed_from_blog);
    }

    public entry fun update(
        account: &signer,
        name: String,
        articles: vector<u128>,
        is_emergency: bool,
    ) {
        let blog_state = blog_state::remove_blog_state();
        let blog_state_updated = blog_state_update_logic::verify(
            account,
            name,
            articles,
            is_emergency,
            &blog_state,
        );
        let updated_blog_state = blog_state_update_logic::mutate(
            account,
            &blog_state_updated,
            blog_state,
        );
        blog_state::update_version_and_add(updated_blog_state);
        blog_state::emit_blog_state_updated(blog_state_updated);
    }

    public entry fun delete(
        account: &signer,
    ) {
        let blog_state = blog_state::remove_blog_state();
        let blog_state_deleted = blog_state_delete_logic::verify(
            account,
            &blog_state,
        );
        let updated_blog_state = blog_state_delete_logic::mutate(
            account,
            &blog_state_deleted,
            blog_state,
        );
        blog_state::drop_blog_state(updated_blog_state);
        blog_state::emit_blog_state_deleted(blog_state_deleted);
    }

}
