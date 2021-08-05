// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/Ownable.sol";
import "./IPStorage.sol";
import "./GPStorage.sol";
import "./VaultStorage.sol";
import "./LPStorage.sol";

contract NPStorage is Ownable {
    uint256 constant RATIO_FACTOR = 1000000;

    uint32 public minRatio = uint32(RATIO_FACTOR * 5 / 10000);
    uint32 public alpha = 0;
    uint32 public raiseRatio = uint32(RATIO_FACTOR * 1);
    // Lowest swap boundary
    uint32 public raiseLPLossRatio = 800000;

    uint256 public auctionDuration = 7 days;
    uint256 public raisingDuration = 3 days;
    uint256 public minimumDuration = 90 days;

    address public DGTToken;
    address public DGTBeneficiary;

    IPStorage public _IPS;
    GPStorage public _GPS;
    LPStorage public _LPS;
    VaultStorage public _VTS;

    event SetMinRatio(uint32 _MinRatio);
    event SetAlpha(uint32 _Alpha);
    event SetRaiseRatio(uint32 _RaiseRatio);
    event SetDuration(uint256 _AuctionDuration, uint256 _RaisingDuration, uint256 _MinimumDuration);

    function setMinRatio(uint32 _minRatio) external onlyOwner {
        minRatio = _minRatio;
        emit SetMinRatio(minRatio);
    }

    function setAlpha(uint32 _alpha) external onlyOwner {
        alpha = _alpha;
        emit SetAlpha(alpha);
    }

    function setRaiseRatio(uint32 _raiseRatio) external onlyOwner {
        raiseRatio = _raiseRatio;
        emit SetRaiseRatio(raiseRatio);
    }

    function setDuration(uint256 _auction, uint256 _raising, uint256 _duration) external onlyOwner {
        require(_auction > 0 && _raising > 0 && _duration >= 2 * _raising,
                "Wrong Duration");
        auctionDuration = _auction;
        raisingDuration = _raising;
        minimumDuration = _duration;
        emit SetDuration(auctionDuration, raisingDuration, minimumDuration);
    }
}