const ethPrice = 2000
const usdcPrice = 1
const ethBal = 10;
const usdcBal = 40000;
const rate = 1/2
const slippage = 0.01

async function main() {
    lp(10, 0)
}

function lp(ethAmt, usdcAmt) {
    let net;
    const ethVal = (ethBal + ethAmt) * ethPrice;
    const usdcVal = (usdcBal + usdcAmt) * usdcPrice;
    if (ethVal > usdcVal) {
        const 
    } else if (usdcVal > ethVal) {

    } else {

    }

    console.log(net)
}

function swap(ethAmt, usdcAmt) {
    let remaining = ethAmt ? ethAmt : usdcAmt;
    if (ethAmt > 0) {
        while (remaining > 0) {
            
        }
    }   
    
    if (usdcAmt > 0) {

    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
