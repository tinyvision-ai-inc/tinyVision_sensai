component lsc_ml_ice40_cnn is
    port(i_fifo_empty: in std_logic;
         o_status: out std_logic_vector(7 downto 0);
         o_rd_rdy: out std_logic;
         o_fc_cycles: out std_logic_vector(31 downto 0);
         resetn: in std_logic;
         o_dout: out std_logic_vector(15 downto 0);
         clk: in std_logic;
         i_fifo_dout: in std_logic_vector(31 downto 0);
         i_start: in std_logic;
         o_we: out std_logic;
         i_we: in std_logic;
         i_debug_rdy: in std_logic;
         o_cycles: out std_logic_vector(31 downto 0);
         o_debug_vld: out std_logic;
         i_din: in std_logic_vector(15 downto 0);
         o_fifo_rd: out std_logic;
         i_fifo_low: in std_logic;
         i_waddr: in std_logic_vector(15 downto 0);
         o_commands: out std_logic_vector(31 downto 0);
         o_fill: out std_logic);
end component;

__: lsc_ml_ice40_cnn port map(i_fifo_empty=> , o_status=> , o_rd_rdy=> ,
    o_fc_cycles=> , resetn=> , o_dout=> , clk=> , i_fifo_dout=> , i_start=> ,
    o_we=> , i_we=> , i_debug_rdy=> , o_cycles=> , o_debug_vld=> , i_din=> ,
    o_fifo_rd=> , i_fifo_low=> , i_waddr=> , o_commands=> , o_fill=> );