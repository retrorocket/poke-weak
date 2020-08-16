## 概要

* ポケモンの相性チェック用LINE Botです
  - LINEに防御側のタイプ名、またはポケモンの日本語の名前を投稿すると、攻撃側の相性を返却します。
* 動作させるために以下を `/data` に配置する必要があります
  - [dayu282/pokemon\-data\.json: all Gen 8 data](https://github.com/dayu282/pokemon-data.json) -> `gen8-jp.json`
  - [kotofurumiya/pokemon\_data: 全ポケモンのJSONデータです。](https://github.com/kotofurumiya/pokemon_data) -> `pokemon_data.json`

![](./screen.png)

## 相性表の情報元

[バトルに役立つ！ タイプ相性表を公開！｜『ポケットモンスター サン・ムーン』公式サイト](https://www.pokemon.co.jp/ex/sun_moon/fight/161215_01.html)

## 起動方法
`hypnotoad weak_calc.pl`
