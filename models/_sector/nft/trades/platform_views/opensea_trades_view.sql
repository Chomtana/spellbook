
{{ config(
        schema = 'opensea',
        alias = alias('trades'),
        tags = ['dunesql'],
        materialized = 'view',
        post_hook='{{ expose_spells(\'["ethereum", "solana", "polygon"]\',
                                    "project",
                                    "opensea",
                                    \'["0xRob"]\') }}')
}}

SELECT *
FROM {{ ref('nft_trades') }}
WHERE project = 'opensea'
