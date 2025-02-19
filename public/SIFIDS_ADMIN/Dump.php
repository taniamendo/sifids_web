<?php

declare(strict_types=1);

namespace SIFIDS_ADMIN;

class Dump {
    private $action = NULL;
    private $startDate = NULL;
    private $endDate = NULL;
    private $db = NULL;
    private $fh = NULL;
    
    public function __construct(string $action) { //{{{
        $this->action = $action;
        
        $this->db = DB::getInstance();
        $this->db->setFetch(\PDO::FETCH_NUM);
    }
    
    public function setStartDate(string $d) { //{{{
        $this->startDate = $d;
    }
    //}}}

    public function setEndDate(string $d) { //{{{
        $this->endDate = $d;
    }
    //}}}
    
    public function generateDump() : string { //{{{
        $filename = $this->action;
        
        // make sure that required params are present
        switch ($this->action) {
            // these need start and end dates
         case 'trips':
         case 'trip_estimates':
         case 'tracks':
         case 'track_analysis':
         case 'app_creels':
         case 'app_catch':
         case 'app_observations':
            if (!$this->startDate || !$this->endDate) {
                throw new \Exception('Need start and end dates for trips data');
            }
            
            $filename = sprintf('%s_%s_%s',
                                $filename, $this->startDate, $this->endDate);
            break;
            
         default:
            break;
        }
        
        // get results from database
        $results = $this->{$this->action}();
        
        // open memory file handle
        $this->fh = fopen('php://memory', 'r+');
        
        // write CSV data to file handle
        foreach ($results as $row) {
            fputcsv($this->fh, $row);
        }
        
        // finished
        rewind($this->fh);
        
        return $filename;
    }
    //}}}
    
    // magic method for creating string representation of object
    public function __toString() : string { //{{{
        // send back CSV as string
        return stream_get_contents($this->fh);
    }
    //}}}

    // return data on trips made within date range
    private function trips() : array { //{{{
        return $this->db->dumpTrip($this->startDate, $this->endDate);
    }
    //}}}

    // return data on trip estimates made within date range
    private function trip_estimates() : array { //{{{
        return $this->db->dumpTripEstimates($this->startDate, $this->endDate);
    }
    //}}}

    // return data on tracks made within date range
    private function tracks() : array { //{{{
        return $this->db->dumpTracks($this->startDate, $this->endDate);
    }
    //}}}

    // return data on track analysis made within date range
    private function track_analysis() : array { //{{{
        return $this->db->dumpTrackAnalysis($this->startDate, $this->endDate);
    }
    //}}}

    // return data on vessels
    private function vessels() : array { //{{{
        return $this->db->dumpVessels();
    }
    //}}}

    // return data on grids
    private function grids() : array { //{{{
        return $this->db->dumpGrids();
    }
    //}}}

    // return data on creels entered into app
    private function app_creels() : array { //{{{
        return $this->db->dumpAppCreels($this->startDate, $this->endDate);
    }
    //}}}

    // return data on catch entered into app
    private function app_catch() : array { //{{{
        return $this->db->dumpAppCatch($this->startDate, $this->endDate);
    }
    //}}}

    // return data on observations entered into app
    private function app_observations() : array { //{{{
        return $this->db->dumpAppObservations($this->startDate, $this->endDate);
    }
    //}}}
}

?>