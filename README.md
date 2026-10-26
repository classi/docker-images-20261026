# docker-images-20261026

Ruby と PHP のベースイメージを、公式 Docker イメージ（Docker Official Image）と同じ Dockerfile でソースからビルドし、GitHub Container Registry（ghcr）に push する仕組みです。
言語本体に緊急のセキュリティリリースが出たとき、公式イメージの更新を待たずに、修正済みのベースイメージを用意するために使います。

方式は pixiv の [PHP 8.5.12 緊急パッチ対応](https://inside.pixiv.blog/2026/10/22/193321) を参考にしています。
このリポジトリを作った経緯は、[Classi開発者ブログの記事](https://tech.classi.jp/entry/2026/10/26/163000) に書いています。

このリポジトリには、公式イメージの Dockerfile を含めていません。
使う前に、次の節の手順で、docker-library/ruby と docker-library/php から Dockerfile をコピーしてください。

## Dockerfile の用意

`ruby/` と `php/` の下には、ディレクトリの構成だけを `.gitkeep` で置いています。
それぞれのディレクトリに、docker-library の同じパスのディレクトリの中身をコピーします。

| このリポジトリのディレクトリ | コピー元 |
|---|---|
| `ruby/<minor>/<variant>/` | [docker-library/ruby](https://github.com/docker-library/ruby) の `<minor>/<variant>/`（Dockerfile） |
| `php/<minor>/<distro>/<variant>/` | [docker-library/php](https://github.com/docker-library/php) の `<minor>/<distro>/<variant>/`（Dockerfile と、`docker-php-ext-install` などの補助スクリプト） |

```sh
git clone --depth 1 https://github.com/docker-library/ruby.git /tmp/docker-library-ruby
cp -R /tmp/docker-library-ruby/4.0/slim-trixie/. ruby/4.0/slim-trixie/

git clone --depth 1 https://github.com/docker-library/php.git /tmp/docker-library-php
cp -R /tmp/docker-library-php/8.5/trixie/fpm/. php/8.5/trixie/fpm/
```

コピーした Dockerfile では、バージョン、ダウンロード URL、SHA256 を `ENV` で直接指定しています。
これを `ARG` で受け取るように書き換え、Bake から値を渡せるようにします。
公式イメージでは実行時にこれらの値が環境変数として見えるので、`ENV` も残します。

Ruby の場合は、次のように書き換えます。

```diff
-ENV RUBY_VERSION 4.0.8
-ENV RUBY_DOWNLOAD_URL https://cache.ruby-lang.org/pub/ruby/4.0/ruby-4.0.8.tar.xz
-ENV RUBY_DOWNLOAD_SHA256 3bd35abc39dce9c682d62cf333fbd8b8f34816dd651f8228b3b59353157b84a4
+ARG RUBY_VERSION=4.0.8
+ARG RUBY_DOWNLOAD_URL=https://cache.ruby-lang.org/pub/ruby/4.0/ruby-4.0.8.tar.xz
+ARG RUBY_DOWNLOAD_SHA256=3bd35abc39dce9c682d62cf333fbd8b8f34816dd651f8228b3b59353157b84a4
+ENV RUBY_VERSION $RUBY_VERSION
+ENV RUBY_DOWNLOAD_URL $RUBY_DOWNLOAD_URL
+ENV RUBY_DOWNLOAD_SHA256 $RUBY_DOWNLOAD_SHA256
```

PHP の場合は、次のように書き換えます。

```diff
-ENV PHP_VERSION 8.5.12
-ENV PHP_URL="https://www.php.net/distributions/php-8.5.12.tar.xz" PHP_ASC_URL="https://www.php.net/distributions/php-8.5.12.tar.xz.asc"
-ENV PHP_SHA256="08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209"
+ARG PHP_VERSION=8.5.12
+ARG PHP_URL="https://www.php.net/distributions/php-8.5.12.tar.xz"
+ARG PHP_ASC_URL="https://www.php.net/distributions/php-8.5.12.tar.xz.asc"
+ARG PHP_SHA256="08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209"
+ENV PHP_VERSION $PHP_VERSION
+ENV PHP_URL="$PHP_URL" PHP_ASC_URL="$PHP_ASC_URL"
+ENV PHP_SHA256="$PHP_SHA256"
```

それ以外の部分は、コピーしたまま変えません。
docker-library の更新を取り込むときに、差分を追いやすくするためです。

対象のマイナーバージョンや variant を増やす場合は、ディレクトリを足したうえで、Bake の定義（`docker-bake.ruby.hcl`、`docker-bake.php.hcl`）の validation と matrix に項目を足します。

## ビルドされるイメージとタグ

| 言語 | 対象のバージョン | variant |
|---|---|---|
| Ruby | 3.3、3.4、4.0 | slim-trixie、slim-bookworm |
| PHP | 8.2、8.3、8.4、8.5 | cli、fpm、apache（それぞれ trixie と bookworm） |

タグは公式イメージと同じ体系です。

| イメージ | 付くタグ（4.0.9、8.5.12 の例） |
|---|---|
| Ruby slim-trixie | `4.0.9-slim-trixie`、`4.0-slim-trixie`、`4.0.9-slim`、`4.0-slim` |
| Ruby slim-bookworm | `4.0.9-slim-bookworm`、`4.0-slim-bookworm` |
| PHP cli（trixie） | `8.5.12-cli-trixie`、`8.5-cli-trixie`、`8.5.12-trixie`、`8.5-trixie`、`8.5.12-cli`、`8.5-cli`、`8.5.12`、`8.5` |
| PHP cli（bookworm） | `8.5.12-cli-bookworm`、`8.5-cli-bookworm`、`8.5.12-bookworm`、`8.5-bookworm` |
| PHP fpm / apache（trixie） | `8.5.12-fpm-trixie`、`8.5-fpm-trixie`、`8.5.12-fpm`、`8.5-fpm`（apache も同じ形） |
| PHP fpm / apache（bookworm） | `8.5.12-fpm-bookworm`、`8.5-fpm-bookworm`（apache も同じ形） |

タグの体系が同じなので、アプリの Dockerfile では、`FROM` のレジストリの部分を置き換えるだけで切り替えられます。

公式イメージにある `4-slim`、`8-fpm`、`slim`、`fpm`、`latest` のようなタグは付けません。
これらは「メジャーバージョンで最新」や「全体で最新」を指すタグであり、あるマイナーバージョンのビルドが付けると、より新しいマイナーバージョンのイメージを古いもので上書きしてしまうからです。

push 先は `ghcr.io/classi/ruby` と `ghcr.io/classi/php` です。
別の場所に push する場合は、Bake の定義の `REGISTRY_IMAGES` のデフォルト値を書き換えてください。

## ビルドの起動

### 1. ワークフローを起動する

GitHub の Actions の画面から `build-ruby` または `build-php` を選び、バージョンと、配布物（`.tar.xz`）の SHA256 を入力して実行します。
SHA256 は、Ruby は `https://cache.ruby-lang.org/pub/ruby/index.txt` に、PHP は `https://www.php.net/releases/index.php?json&version=<version>` に載っています。
CLI からは次のように起動できます。

```sh
gh workflow run build-ruby.yml --ref main \
  -f ruby_version=4.0.9 \
  -f sha256=a8057adb39f51ad6dc3106237504c93dd792bb515837b4fe7817ae21ed7e51f4

gh workflow run build-php.yml --ref main \
  -f php_version=8.5.12 \
  -f sha256=08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209
```

1 回の起動で、そのバージョンの全 variant をビルドします。
複数のマイナーバージョンに同時にリリースが出た場合は、バージョンごとに起動します。

### 2. 結果を確認する

ワークフローは次の順に進みます。

1. `plan` job: Bake の定義から、ビルドする target の一覧を作ります。
2. `build (<target>)` job: target ごとに別のランナーで、ビルド、スモークテスト、push を行います。

スモークテストに失敗した target は push されません。
`fail-fast: false` にしているので、一部の target が失敗しても、ほかの target はビルドと push を続けます。

## ローカルでのビルドとスモークテスト

バージョンと SHA256 は必須です。指定しないと、Bake の検証で止まります。
`REGISTRY_IMAGES` でタグのリポジトリ名を変えられるので、ローカルでは ghcr の名前を使わずにビルドできます。

```sh
# Ruby
RUBY_VERSION=4.0.9 \
RUBY_DOWNLOAD_SHA256=a8057adb39f51ad6dc3106237504c93dd792bb515837b4fe7817ae21ed7e51f4 \
REGISTRY_IMAGES=ruby-local \
  docker buildx bake -f docker-bake.ruby.hcl --load ruby-slim-trixie
./test/smoke-ruby.sh ruby-local:4.0.9-slim-trixie 4.0.9

# PHP
PHP_VERSION=8.5.12 \
PHP_SHA256=08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209 \
REGISTRY_IMAGES=php-local \
  docker buildx bake -f docker-bake.php.hcl --load php-fpm-trixie
./test/smoke-php.sh php-local:8.5.12-fpm-trixie 8.5.12 fpm
```

## 既知の制約

- PHP の GPG の署名の検証では、公式イメージの Dockerfile のとおり、ビルドのたびに `keyserver.ubuntu.com` から公開鍵を取得します。鍵サーバーが止まっていると、PHP のビルドは失敗します。
- ビルドは amd64 だけです。
- アプリが依存する native extension を持つ gem や PECL の拡張は、このリポジトリの対象外です。

## ライセンス

[Unlicense](LICENSE) です。
docker-library からコピーする Dockerfile と補助スクリプトには、docker-library/ruby と docker-library/php のライセンスが適用されます。
