# elasticsearch-rails-ha RubyGem

Elasticsearch for Rails, high availability extensions.

See also:

* [elasticsearch-rails](https://github.com/elastic/elasticsearch-rails)

## Examples

Add the high availability tasks to your Rake task file `lib/tasks/elasticsearch.rake`:

```
require 'elasticsearch/rails/ha/tasks'
```

Import all the Articles on a machine with 4 cores available:

```
% bundle exec rake environment elasticsearch:ha:import NPROCS=4 CLASS='Article'
```

Stage an index alongside your live index, but do not make it live yet:

```
% bundle exec rake environment elasticsearch:ha:stage NPROCS=4 CLASS='Article'
```

Promote your staged index:

```
% bundle exec rake environment elasticsearch:ha:promote
```

## Acknowledgements

Thanks to [Pop Up Archive](http://popuparchive.com/) for
contributing the [original version of this code](https://github.com/popuparchive/pop-up-archive/blob/master/lib/tasks/search.rake) to the public domain.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0
> dedication. By submitting a pull request, you are agreeing to comply
> with this waiver of copyright interest.
