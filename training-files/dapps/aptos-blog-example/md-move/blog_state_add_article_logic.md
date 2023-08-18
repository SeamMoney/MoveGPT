```rust
module aptos_blog_demo::blog_state_add_article_logic {
    use std::vector;

    use aptos_blog_demo::article_added_to_blog;
    use aptos_blog_demo::blog_state;

    friend aptos_blog_demo::blog_state_aggregate;

    public(friend) fun verify(
        article_id: u128,
        blog_state: &blog_state::BlogState,
    ): blog_state::ArticleAddedToBlog {
        blog_state::new_article_added_to_blog(
            blog_state,
            article_id,
        )
    }

    public(friend) fun mutate(
        article_added_to_blog: &blog_state::ArticleAddedToBlog,
        blog_state: blog_state::BlogState,
    ): blog_state::BlogState {
        let article_id = article_added_to_blog::article_id(article_added_to_blog);
        let articles = blog_state::articles(&blog_state);
        if (!vector::contains(&articles, &article_id)) {
            vector::push_back(&mut articles, article_id);
            blog_state::set_articles(&mut blog_state, articles);
        };
        blog_state
    }
}

```