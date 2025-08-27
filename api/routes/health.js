const express = require('express');
const router = express.Router();
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');

// GET /api/health - Basic health check
router.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    memory: {
      used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB',
      total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB'
    }
  });
});

// GET /api/health/blockchain - Blockchain network health check
router.get('/blockchain', async (req, res) => {
  try {
    // Attempt to connect to the blockchain network
    const ccpPath = path.resolve(__dirname, '..', '..', 'network', 'organizations', 'peerOrganizations', 'org1.medical.com', 'connection-org1.json');
    
    const walletPath = path.join(process.cwd(), 'wallet');
    const wallet = await Wallets.newFileSystemWallet(walletPath);

    const identity = await wallet.get('appUser');
    if (!identity) {
      return res.status(503).json({
        status: 'unhealthy',
        error: 'Blockchain identity not found',
        message: 'User identity "appUser" does not exist in wallet',
        timestamp: new Date().toISOString()
      });
    }

    const gateway = new Gateway();
    
    try {
      await gateway.connect(ccpPath, {
        wallet,
        identity: 'appUser',
        discovery: { enabled: true, asLocalhost: true }
      });

      const network = await gateway.getNetwork('medical-channel');
      const contract = network.getContract('medical-diagnosis-chaincode');

      // Try a simple query to test connectivity
      await contract.evaluateTransaction('ListDiagnosisForms');

      res.json({
        status: 'healthy',
        blockchain: {
          connected: true,
          network: 'medical-channel',
          contract: 'medical-diagnosis-chaincode'
        },
        timestamp: new Date().toISOString()
      });
    } finally {
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Blockchain health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      error: 'Blockchain connection failed',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// GET /api/health/detailed - Detailed system health check
router.get('/detailed', async (req, res) => {
  const startTime = Date.now();
  
  try {
    // Check basic system health
    const systemHealth = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch
    };

    // Memory usage
    const memUsage = process.memoryUsage();
    systemHealth.memory = {
      heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + ' MB',
      heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024) + ' MB',
      rss: Math.round(memUsage.rss / 1024 / 1024) + ' MB',
      external: Math.round(memUsage.external / 1024 / 1024) + ' MB'
    };

    // CPU usage (simplified)
    const cpuUsage = process.cpuUsage();
    systemHealth.cpu = {
      user: cpuUsage.user,
      system: cpuUsage.system
    };

    // Check blockchain connectivity
    let blockchainHealth;
    try {
      const ccpPath = path.resolve(__dirname, '..', '..', 'network', 'organizations', 'peerOrganizations', 'org1.medical.com', 'connection-org1.json');
      const walletPath = path.join(process.cwd(), 'wallet');
      const wallet = await Wallets.newFileSystemWallet(walletPath);
      
      const identity = await wallet.get('appUser');
      if (identity) {
        const gateway = new Gateway();
        try {
          await gateway.connect(ccpPath, {
            wallet,
            identity: 'appUser',
            discovery: { enabled: true, asLocalhost: true }
          });

          const network = await gateway.getNetwork('medical-channel');
          const contract = network.getContract('medical-diagnosis-chaincode');
          
          // Test query
          await contract.evaluateTransaction('ListDiagnosisForms');
          
          blockchainHealth = {
            status: 'healthy',
            connected: true,
            network: 'medical-channel',
            contract: 'medical-diagnosis-chaincode'
          };
        } finally {
          await gateway.disconnect();
        }
      } else {
        blockchainHealth = {
          status: 'warning',
          connected: false,
          error: 'Identity not found in wallet'
        };
      }
    } catch (error) {
      blockchainHealth = {
        status: 'unhealthy',
        connected: false,
        error: error.message
      };
    }

    const responseTime = Date.now() - startTime;
    
    const overallStatus = blockchainHealth.status === 'healthy' ? 'healthy' : 'degraded';

    res.json({
      overall: {
        status: overallStatus,
        responseTime: responseTime + 'ms',
        timestamp: new Date().toISOString()
      },
      components: {
        system: systemHealth,
        blockchain: blockchainHealth
      }
    });
  } catch (error) {
    console.error('Detailed health check failed:', error);
    res.status(503).json({
      overall: {
        status: 'unhealthy',
        responseTime: (Date.now() - startTime) + 'ms',
        timestamp: new Date().toISOString()
      },
      error: error.message
    });
  }
});

module.exports = router;
