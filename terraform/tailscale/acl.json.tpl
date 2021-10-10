// Example/default ACLs for unrestricted connections.
{
    // Declare static groups of users beyond those in the identity service.
    "groups": {
      "group:admins": [
          "${user}",
        ],
    },
    // Declare convenient hostname aliases to use in place of IP addresses.
    "hosts": {
      "example-host-1": "100.100.100.100",
    },
    // Access control lists.
    "acls": [
      // Match absolutely everything. Comment out this section if you want
      // to define specific ACL restrictions.
      { "action": "accept", "users": ["*"], "ports": ["*:*"] },
    ]
}
 