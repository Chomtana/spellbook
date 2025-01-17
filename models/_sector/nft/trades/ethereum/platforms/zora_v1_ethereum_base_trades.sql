{{ config(
    schema = 'zora_v1_ethereum',
    tags = ['dunesql'],
    alias = alias('base_trades'),
    materialized = 'incremental',
    file_format = 'delta',
    incremental_strategy = 'merge',
    unique_key = ['block_number','tx_hash','sub_tx_trade_id'],
    )
}}

SELECT
      bf.evt_block_time AS block_time
    , bf.evt_block_number AS block_number
    , bf.contract_address AS project_contract_address
    , bf.evt_tx_hash AS tx_hash
    , 0xabefbc9fd2f806065b4f3c237d4b59d9a97bcac7 AS nft_contract_address -- hardcoded ZORA address
    , bf.tokenId AS nft_token_id
    , CAST(1 as UINT256) as nft_amount
    , 'Offer accepted' AS trade_category
    , CASE WHEN mt."from" = mint.to
        THEN 'primary'
        ELSE 'secondary'
        END AS trade_type
    , from_hex(JSON_EXTRACT_SCALAR(bf.bid, '$.bidder')) AS buyer
    , mt."from" AS seller
    , CAST(JSON_EXTRACT_SCALAR(bf.bid, '$.amount') as UINT256) AS price_raw
    , from_hex(JSON_EXTRACT_SCALAR(bf.bid, '$.currency')) AS currency_contract
    , CAST(0 as UINT256) AS platform_fee_amount_raw
    , CAST(0 as UINT256) AS royalty_fee_amount_raw
    , CAST(NULL as varbinary) AS platform_fee_address
    , CAST(NULL as varbinary) AS royalty_fee_address
    , bf.evt_index as sub_tx_trade_id
FROM {{ source('zora_ethereum','Market_evt_BidFinalized') }} bf
LEFT JOIN {{ source('zora_ethereum','Media_evt_Transfer') }} mint
    ON mint."from" = 0x0000000000000000000000000000000000000000
    AND mint.tokenId = bf.tokenId
LEFT JOIN {{ source('zora_ethereum','Media_evt_Transfer') }} mt
    ON bf.evt_block_number = mt.evt_block_number
    AND bf.evt_tx_hash = mt.evt_tx_hash
    AND bf.tokenId = mt.tokenId
    AND from_hex(JSON_EXTRACT_SCALAR(bf.bid, '$.bidder')) = mt.to
WHERE from_hex(JSON_EXTRACT_SCALAR(bf.bid, '$.bidder')) != 0xe468ce99444174bd3bbbed09209577d25d1ad673   -- these are sells through the auction house which are included in V2
{% if is_incremental() %}
AND bf.evt_block_time >= date_trunc('day', now() - interval '7' day)
AND mt.evt_block_time >= date_trunc('day', now() - interval '7' day)
{% endif %}
